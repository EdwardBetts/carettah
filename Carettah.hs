module Main where
import System
import System.Mem
import Data.Char
import Data.Bits
import Data.IORef
import Data.Time
import System.IO.Unsafe (unsafePerformIO)
import Control.Monad.Reader
--import Control.Monad.State
--import Control.Monad.Trans
import qualified Graphics.UI.Gtk as G
import qualified Graphics.Rendering.Cairo as C
import qualified Text.Pandoc as P

data CairoPosition = CairoPosition Double | CairoCenter
                   deriving Show
data CairoSize = CairoSize Double | CairoFit
                   deriving Show

markdown :: String -> P.Pandoc
markdown = P.readMarkdown P.defaultParserState{ P.stateStandalone = True }

-- global value
data CarettahState = CarettahState {
  page :: Int,
  slides :: [[Double -> C.Render Double]],
  startTime :: UTCTime
  }

carettahState :: IORef CarettahState
carettahState = unsafePerformIO $ newIORef CarettahState { page = 0, slides = undefined, startTime = undefined }

updateCarettahState :: MonadIO m => (CarettahState -> CarettahState) -> m ()
updateCarettahState fn = liftIO $! atomicModifyIORef carettahState $ \st -> (fn st, ())

queryCarettahState :: MonadIO m => (CarettahState -> a) -> m a
queryCarettahState fn = liftM fn $ liftIO $! readIORef carettahState

updatePage :: MonadIO m => (Int -> Int) -> m ()
updatePage fn = updateCarettahState (\s -> s { page = fn $ page s })

nextPage, prevPage :: MonadIO m => m ()
nextPage = do s <- queryCarettahState slides
              let maxpage = length s - 1
              updatePage (\p -> if p >= maxpage then maxpage else p + 1)
prevPage = updatePage (\p -> if p == 0 then 0 else p - 1)

updateSlides :: MonadIO m => ([[Double -> C.Render Double]] -> [[Double -> C.Render Double]]) -> m ()
updateSlides fn = updateCarettahState (\s -> s { slides = fn $ slides s })

updateStartTime :: IO ()
updateStartTime = do
  t <- getCurrentTime
  updateCarettahState (\s -> s { startTime = t })

-- constant value
data Config = Config {
  --- posX,posY,fsizeの値は640x480の画面サイズが基準
  canvasW :: Int,
  canvasH :: Int,
  alphaBackG :: Double,
  textTitleY :: Double,
  textTitleSize :: Double,
  textContextY :: Double,
  textContextSize :: Double,
  textTitleCoverY :: Double,
  textTitleCoverSize :: Double,
  textContextX :: Double,
  textContextCoverY :: Double,
  textContextCoverSize :: Double,
  textCodeBlockSize :: Double,
  turtleSize :: Double,
  waveSize :: Double
  }
gCfg :: Config
gCfg = Config {
  canvasW   = 640,
  canvasH  = 480,
  alphaBackG = 0.3,
  textTitleCoverY = 170,
  textTitleCoverSize = 40,
  textContextCoverY = 300,
  textContextCoverSize = 30,
  textTitleY = 60,
  textTitleSize = 40,
  textContextX = 40,
  textContextY = 150,
  textContextSize = 30,
  textCodeBlockSize = 20,
  turtleSize = 40,
  waveSize = 20
  }

toDouble :: Integral a => a -> Double
toDouble = fromIntegral

-- copy from System.Glib.UTFString (gtk2hs/glib/System/Glib/UTFString.hs)
-- 本来はCStringを使うとこに埋め込んどくべき。gtk2hsを参考に
toUTF :: String -> String
toUTF [] = []
toUTF (x:xs) | ord x<=0x007F = x:toUTF xs
	     | ord x<=0x07FF = chr (0xC0 .|. ((ord x `shift` (-6)) .&. 0x1F)):
			       chr (0x80 .|. (ord x .&. 0x3F)):
			       toUTF xs
	     | otherwise     = chr (0xE0 .|. ((ord x `shift` (-12)) .&. 0x0F)):
			       chr (0x80 .|. ((ord x `shift` (-6)) .&. 0x3F)):
			       chr (0x80 .|. (ord x .&. 0x3F)):
			       toUTF xs

mySetFontSize :: Double -> C.Render ()
mySetFontSize fsize = do
  C.selectFontFace (toUTF "Takao P明朝") C.FontSlantNormal C.FontWeightNormal
  C.setFontSize fsize

renderText :: CairoPosition -> CairoPosition -> Double -> String -> C.Render Double
renderText x y fsize text = do
  C.save
  mySetFontSize fsize
  (C.TextExtents _ _ w h _ _) <- C.textExtents (toUTF text)
  C.restore
  let truePosition (CairoPosition x') (CairoPosition y') = return (x', y')
      truePosition CairoCenter (CairoPosition y') =
          return (toDouble (canvasW gCfg) / 2 - w / 2, y')
      truePosition x' y' =
        error $ "called with x=" ++ show x' ++ " y=" ++ show y'
  (xt, yt) <- truePosition x y
  let nypos = yt + (h * 1.4)
  C.save
  mySetFontSize fsize
  C.moveTo xt nypos
  C.textPath $ toUTF text
  C.fill >> C.stroke >> C.restore
  return nypos

renderSurface :: Double -> Double -> Double -> C.Surface -> C.Render ()
renderSurface x y alpha surface = do
  C.save
  C.setSourceSurface surface x y
  C.paintWithAlpha alpha
  C.restore

pngSurfaceSize :: FilePath -> C.Render (C.Surface, Int, Int)
pngSurfaceSize file = do
  surface <- liftIO $ C.imageSurfaceCreateFromPNG file
  w <- C.imageSurfaceGetWidth surface
  h <- C.imageSurfaceGetHeight surface
  return (surface, w, h)

renderPngSize :: Double -> Double -> Double -> Double -> Double -> FilePath -> C.Render Double
renderPngSize x y w h alpha file = do
  C.save
  (surface, iw, ih) <- pngSurfaceSize file
  let xscale = w / toDouble iw
  let yscale = h / toDouble ih
  C.scale xscale yscale
  renderSurface (x / xscale) (y / yscale) alpha surface
  C.restore
  return $ y + h

renderPngFit :: Double -> FilePath -> C.Render ()
renderPngFit alpha file = do
  C.save
  (surface, iw, ih) <- pngSurfaceSize file
  let cw = toDouble $ canvasW gCfg
      ch = toDouble $ canvasH gCfg
  C.scale (cw / toDouble iw) (ch / toDouble ih)
  renderSurface 0 0 alpha surface
  C.restore

clearCanvas :: Int -> Int -> C.Render ()
clearCanvas w h = do
  C.save
  C.setSourceRGB 1 1 1
  C.rectangle 0 0 (toDouble w) (toDouble h)
  C.fill >> C.stroke >> C.restore

-- xxx プレゼン時間に応じて波表示
elapsedSecFromStart :: IO Double
elapsedSecFromStart = do
  n <- getCurrentTime
  s <- queryCarettahState startTime
  let d = diffUTCTime n s
  return $ (fromRational . toRational) d

renderWave :: C.Render ()
renderWave = do
  sec <- liftIO elapsedSecFromStart
  let ws = waveSize gCfg
      ch = toDouble $ canvasH gCfg
  _ <- renderText (CairoPosition 0) (CairoPosition $ ch - ws) ws $ replicate (round sec) '>'
  return ()

renderTurtle :: Double -> C.Render ()
renderTurtle progress =
  renderPngSize (ts / 2 + (cw - ts * 2) * progress) (ch - ts) ts ts 1 "turtle.png" >> return ()
    where ts = turtleSize gCfg
          cw = toDouble $ canvasW gCfg
          ch = toDouble $ canvasH gCfg

splitBlocks :: P.Pandoc -> [[P.Block]]
splitBlocks (P.Pandoc _ blocks) = go blocks
  where go (P.Header 1 h:xs) = let (b1, b2) = break (\a -> case a of
                                                      (P.Header 1 _) -> True
                                                      _ -> False) xs
                             in (P.Header 1 h:b1):go b2
        go _ = []

backgroundTop :: [P.Block] -> [P.Block]
backgroundTop blocks = filter go blocks ++ filter (not . go) blocks
  where go (P.Para [P.Image [P.Str "background"] _]) = True
        go _ = False

inlinesToString :: [P.Inline] -> String
inlinesToString = foldr go ""
  where go (P.Str s) a = s ++ a
        go P.Space a = ' ' : a
        go x _ = show x

yposSequence :: Double -> [Double -> C.Render Double] -> C.Render Double
yposSequence ypos (x:xs) = x ypos >>= (`yposSequence` xs)
yposSequence ypos [] = return ypos

renderSlide :: Int -> Int -> Int -> C.Render ()
renderSlide p w h = do
  s <- queryCarettahState slides
  clearCanvas w h
  let cw = toDouble $ canvasW gCfg
      ch = toDouble $ canvasH gCfg
      tcy = textContextY gCfg
  C.scale (toDouble w / cw) (toDouble h / ch)
  _ <- yposSequence tcy (s !! p)
  renderWave
  renderTurtle $ toDouble p / toDouble (length s - 1)

-- 二枚目以降のスライドをRender
blockToSlide :: [P.Block] -> [Double -> C.Render Double]
blockToSlide blockss = map go blockss
  where
    ag = alphaBackG gCfg
    tty = textTitleY gCfg
    tts = textTitleSize gCfg
    tcx = textContextX gCfg
    tcs = textContextSize gCfg
    tcbs = textCodeBlockSize gCfg
    go :: P.Block -> Double -> C.Render Double
    go (P.Para [P.Image [P.Str "background"] (pngfile, _)]) =
      \y -> renderPngFit ag pngfile >> return y
    go (P.Header 1 strs) =
      \y -> renderText CairoCenter (CairoPosition tty) tts (inlinesToString strs) >> return y
    go (P.BulletList plains) = \y -> yposSequence y $ map go' plains
      where
        go' [P.Plain strs] =
          \ypos -> renderText (CairoPosition tcx) (CairoPosition ypos) tcs ("☆ " ++ inlinesToString strs)
        go' x = error $ show x -- 一部のみをサポート
    go (P.CodeBlock (_, _, _) ss) = \y -> yposSequence y $ map go' (lines ss)
      where
        go' s ypos = renderText (CairoPosition tcx) (CairoPosition ypos) tcbs s >> return (ypos + tcbs)
    go (P.Para strs) =
      \y -> renderText (CairoPosition tcx) (CairoPosition y) tcs (inlinesToString strs)
    go x = error $ show x -- 一部のみをサポート

-- スライド表紙をRender
coverSlide :: [P.Block] -> [Double -> C.Render Double]
coverSlide blocks = map go blocks
  where
    ag = alphaBackG gCfg
    ttcy = textTitleCoverY gCfg
    ttcs = textTitleCoverSize gCfg
    tccy = textContextCoverY gCfg
    tccs = textContextCoverSize gCfg
    go :: P.Block -> Double -> C.Render Double
    go (P.Para [P.Image [P.Str "background"] (pngfile, _)]) =
      \y -> renderPngFit ag pngfile >> return y
    go (P.Header 1 strs) =
      \y -> renderText CairoCenter (CairoPosition ttcy) ttcs (inlinesToString strs) >> return y
    go (P.Para strs) =
      \y -> renderText CairoCenter (CairoPosition tccy) tccs (inlinesToString strs) >> return y
    go x = error $ show x -- 一部のみをサポート

updateCanvas :: G.DrawingArea -> IO ()
updateCanvas canvas = do
  n <- queryCarettahState page
  win <- G.widgetGetDrawWindow canvas
  (width, height) <- G.widgetGetSize canvas
  G.renderWithDrawable win $
    renderSlide n width height
  performGC

main :: IO ()
main = do
  updateStartTime
  -- parse markdown
  args <- getArgs
  s <- case args of
    (x:_) -> readFile x
    _     -> error "*** Need markdown filename."
  let z = zip (coverSlide:repeat blockToSlide) (splitBlocks $ markdown s)
    in updateSlides $ const $ map (\p -> fst p . backgroundTop $ snd p) z
  -- start GUI
  _ <- G.initGUI
  window <- G.windowNew
  canvas <- G.drawingAreaNew
  G.widgetSetSizeRequest window (canvasW gCfg) (canvasH gCfg)
  -- key event
  _ <- window `G.on` G.keyPressEvent $ G.tryEvent $ do
    keyName <- G.eventKeyName
    liftIO $
      case keyName of
        "f" -> G.windowFullscreen window
        "F" -> G.windowUnfullscreen window
        "q" -> G.widgetDestroy window
        "j" -> nextPage >> G.widgetQueueDraw canvas
        "k" -> prevPage >> G.widgetQueueDraw canvas
        "r" -> print "TODO: reload slides" -- xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        _   -> return ()
  _ <- G.onDestroy window G.mainQuit
  _ <- G.onExpose canvas $ const (updateCanvas canvas >> return True)
  _ <- G.timeoutAdd (G.widgetQueueDraw canvas >> return True) 100 -- msec
  G.set window [G.containerChild G.:= canvas]
  G.widgetShowAll window
  G.mainGUI
