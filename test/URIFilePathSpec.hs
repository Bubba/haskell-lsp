{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
module URIFilePathSpec where

import Data.List
import Data.Monoid ((<>))
import Data.Text                              (pack)
import Language.Haskell.LSP.Types

import           Network.URI
import qualified System.FilePath.Windows as FPW
import Test.Hspec
import Test.QuickCheck


-- ---------------------------------------------------------------------

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "URI file path functions" uriFilePathSpec
  describe "file path URI functions" filePathUriSpec

testPosixUri :: Uri
testPosixUri = Uri $ pack "file:///home/myself/example.hs"

testPosixFilePath :: FilePath
testPosixFilePath = "/home/myself/example.hs"

relativePosixFilePath :: FilePath
relativePosixFilePath = "myself/example.hs"

testWindowsUri :: Uri
testWindowsUri = Uri $ pack "file:///c:/Users/myself/example.hs"

testWindowsFilePath :: FilePath
testWindowsFilePath = "c:\\Users\\myself\\example.hs"

uriFilePathSpec :: Spec
uriFilePathSpec = do
  it "converts a URI to a POSIX file path" $ do
    let theFilePath = platformAwareUriToFilePath "posix" testPosixUri
    theFilePath `shouldBe` Just testPosixFilePath

  it "converts a POSIX file path to a URI" $ do
    let theUri = platformAwareFilePathToUri "posix" testPosixFilePath
    theUri `shouldBe` testPosixUri

  it "converts a URI to a Windows file path" $ do
    let theFilePath = platformAwareUriToFilePath windowsOS testWindowsUri
    theFilePath `shouldBe` Just testWindowsFilePath

  it "converts a Windows file path to a URI" $ do
    let theUri = platformAwareFilePathToUri windowsOS testWindowsFilePath
    theUri `shouldBe` testWindowsUri

filePathUriSpec :: Spec
filePathUriSpec = do
  it "converts a POSIX file path to a URI" $ do
    let theFilePath = platformAwareFilePathToUri "posix" "./Functional.hs"
    theFilePath `shouldBe` (Uri "file://./Functional.hs")

  it "converts a Windows file path to a URI" $ do
    let theFilePath = platformAwareFilePathToUri windowsOS "./Functional.hs"
    theFilePath `shouldBe` (Uri "file:///./Functional.hs")

  it "converts a Windows file path to a URI" $ do
    let theFilePath = platformAwareFilePathToUri windowsOS "c:/Functional.hs"
    theFilePath `shouldBe` (Uri "file:///c:/Functional.hs")

  it "converts a POSIX file path to a URI and back" $ do
    let theFilePath = platformAwareFilePathToUri "posix" "./Functional.hs"
    theFilePath `shouldBe` (Uri "file://./Functional.hs")
    let Just (URI scheme' auth' path' query' frag') =  parseURI "file://./Functional.hs"
    (scheme',auth',path',query',frag') `shouldBe`
      ("file:"
      ,Just (URIAuth {uriUserInfo = "", uriRegName = ".", uriPort = ""}) -- AZ: Seems odd
      ,"/Functional.hs"
      ,""
      ,"")
    Just "./Functional.hs" `shouldBe` platformAwareUriToFilePath "posix" theFilePath

  it "converts a Posix file path to a URI and back" $ property $ forAll genPosixFilePath $ \fp -> do
      let uri = platformAwareFilePathToUri "posix" fp
      platformAwareUriToFilePath "posix" uri `shouldBe` Just fp

  it "converts a Windows file path to a URI and back" $ property $ forAll genWindowsFilePath $ \fp -> do
      let uri = platformAwareFilePathToUri windowsOS fp
      -- We normalise to account for changes in the path separator.
      platformAwareUriToFilePath windowsOS uri `shouldBe` Just (FPW.normalise fp)

  it "converts a relative POSIX file path to a URI and back" $ do
    let uri = platformAwareFilePathToUri "posix" relativePosixFilePath
    uri `shouldBe` Uri "file://myself/example.hs"
    let back = platformAwareUriToFilePath "posix" uri
    back `shouldBe` Just relativePosixFilePath

genWindowsFilePath :: Gen FilePath
genWindowsFilePath = do
    segments <- listOf pathSegment
    pathSep <- elements ['/', '\\']
    pure ("C:" <> [pathSep] <> intercalate [pathSep] segments)
  where pathSegment = listOf1 (arbitraryASCIIChar `suchThat` (`notElem` ['/', '\\', '.', ':']))

genPosixFilePath :: Gen FilePath
genPosixFilePath = do
    segments <- listOf pathSegment
    pure ("/" <> intercalate "/" segments)
  where pathSegment = listOf1 (arbitraryASCIIChar `suchThat` (`notElem` ['/', '.']))

#if !MIN_VERSION_QuickCheck(2,10,0)
arbitraryASCIIChar :: Gen Char
arbitraryASCIIChar = arbitrary
#endif
