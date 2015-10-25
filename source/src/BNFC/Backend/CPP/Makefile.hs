module BNFC.Backend.CPP.Makefile (makefile) where

import BNFC.Backend.Common.Makefile
import BNFC.PrettyPrint

makefile :: String -> Doc
makefile name = vcat
    [ mkVar "CC" "g++"
    , mkVar "CCFLAGS" "-g -W -Wall"
    , ""
    , mkVar "FLEX" "flex"
    , mkVar "FLEX_OPTS" ("-P" ++ name)
    , ""
    , mkVar "BISON" "bison"
    , mkVar "BISON_OPTS" ("-t -p" ++ name)
    , ""
    , mkVar "OBJS" "Absyn.o Lexer.o Parser.o Printer.o"
    , ""
    , mkRule ".PHONY" ["clean", "distclean"]
        []
    , mkRule "all" [testName]
        []
    , mkRule "clean" []
        -- peteg: don't nuke what we generated - move that to the "vclean" target.
        [ "rm -f *.o " ++ testName ++ " " ++ unwords
            [ name ++ e | e <- [".aux", ".log", ".pdf",".dvi", ".ps", ""]] ]
    , mkRule "distclean" ["clean"]
        [ "rm -f " ++ unwords
            [ "Absyn.CPP", "Absyn.H", "Test.CPP", "Parser.CPP", "Parser.H", "Lexer.CPP",
              "Skeleton.CPP", "Skeleton.H", "Printer.CPP", "Printer.H", "Makefile " ]
            ++ name ++ ".l " ++ name ++ ".y " ++ name ++ ".tex "]
    , mkRule testName [ "${OBJS}", "Test.o" ]
        [ "@echo \"Linking " ++ testName ++ "...\""
        , "${CC} ${CCFLAGS} ${OBJS} Test.o -o " ++ testName ]
    , mkRule "Absyn.o" [ "Absyn.CPP", "Absyn.H" ]
        [ "${CC} ${CCFLAGS} -c Absyn.CPP" ]
    , mkRule "Lexer.CPP" [ name ++ ".l" ]
        [ "${FLEX} -oLexer.CPP " ++ name ++ ".l" ]
    , mkRule "Parser.CPP" [ name ++ ".y" ]
      [ "${BISON} " ++ name ++ ".y -o Parser.CPP" ]
    , mkRule "Lexer.o" [ "Lexer.CPP", "Parser.H" ]
        [ "${CC} ${CCFLAGS} -c Lexer.CPP " ]
    , mkRule "Parser.o" [ "Parser.CPP", "Absyn.H" ]
        [ "${CC} ${CCFLAGS} -c Parser.CPP" ]
    , mkRule "Printer.o" [ "Printer.CPP", "Printer.H", "Absyn.H" ]
        [ "${CC} ${CCFLAGS} -c Printer.CPP" ]
    , mkRule "Skeleton.o" [ "Skeleton.CPP", "Skeleton.H", "Absyn.H" ]
       [ "${CC} ${CCFLAGS} -c Skeleton.CPP" ]
    , mkRule "Test.o" [ "Test.CPP", "Parser.H", "Printer.H", "Absyn.H" ]
        [ "${CC} ${CCFLAGS} -c Test.CPP" ]
    ]
  where testName = "Test" ++ name
