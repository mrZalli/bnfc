{-
    BNF Converter: C++ Main file
    Copyright (C) 2004  Author:  Markus Forsberg, Michael Pellauer

    Modified from CPPTop to BNFC.Backend.CPP.STL 2006 by Aarne Ranta.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

module BNFC.Backend.CPP.STL (makeCppStl,) where

import BNFC.Utils
import BNFC.CF
import BNFC.Options
import BNFC.Backend.Base
import BNFC.Backend.CPP.Makefile
import BNFC.Backend.CPP.STL.CFtoSTLAbs
import BNFC.Backend.CPP.NoSTL.CFtoFlex
import BNFC.Backend.CPP.STL.CFtoBisonSTL
import BNFC.Backend.CPP.STL.CFtoCVisitSkelSTL
import BNFC.Backend.CPP.PrettyPrinter
import BNFC.Backend.CPP.STL.STLUtils
import Data.Char
import qualified BNFC.Backend.Common.Makefile as Makefile

makeCppStl :: SharedOptions -> CF -> MkFiles ()
makeCppStl opts cf = do
    let (hfile, cfile) = cf2CPPAbs (linenumbers opts) (inPackage opts) name cf
    mkfile "Absyn.H" hfile
    mkfile "Absyn.CPP" cfile
    let (flex, env) = cf2flex (inPackage opts) name cf
    mkfile (name ++ ".l") flex
    let bison = cf2Bison (linenumbers opts) (inPackage opts) name cf env
    mkfile (name ++ ".y") bison
    let header = mkHeaderFile (inPackage opts) cf (allCats cf) (allEntryPoints cf) env
    mkfile "Parser.H" header
    let (skelH, skelC) = cf2CVisitSkel (inPackage opts) cf
    mkfile "Skeleton.H" skelH
    mkfile "Skeleton.CPP" skelC
    let (prinH, prinC) = cf2CPPPrinter True (inPackage opts) cf
    mkfile "Printer.H" prinH
    mkfile "Printer.CPP" prinC
    mkfile "Test.CPP" (cpptest (inPackage opts) cf)
    Makefile.mkMakefile opts $ makefile name
  where name = lang opts


cpptest :: Maybe String -> CF -> String
cpptest inPackage cf =
  unlines
   [
    "/*** Compiler Front-End Test automatically generated by the BNF Converter ***/",
    "/*                                                                          */",
    "/* This test will parse a file, print the abstract syntax tree, and then    */",
    "/* pretty-print the result.                                                 */",
    "/*                                                                          */",
    "/****************************************************************************/",
    "#include <stdio.h>",
    "#include <string.h>",
    "#include \"Parser.H\"",
    "#include \"Printer.H\"",
    "#include \"Absyn.H\"",
    "",
    "void usage() {",
    "  printf(\"usage: Call with one of the following argument " ++
      "combinations:\\n\");",
    "  printf(\"\\t--help\\t\\tDisplay this help message.\\n\");",
    "  printf(\"\\t(no arguments)\tParse stdin verbosely.\\n\");",
    "  printf(\"\\t(files)\\t\\tParse content of files verbosely.\\n\");",
    "  printf(\"\\t-s (files)\\tSilent mode. Parse content of files " ++
      "silently.\\n\");",
    "}",
    "",
    "int main(int argc, char ** argv)",
    "{",
    "  FILE *input;",
    "  int quiet = 0;",
    "  char *filename = NULL;",
    "",
    "  if (argc > 1) {",
    "    if (strcmp(argv[1], \"-s\") == 0) {",
    "      quiet = 1;",
    "      if (argc > 2) {",
    "        filename = argv[2];",
    "      } else {",
    "        input = stdin;",
    "      }",
    "    } else {",
    "      filename = argv[1];",
    "    }",
    "  }",
    "",
    "  if (filename) {",
    "    input = fopen(filename, \"r\");",
    "    if (!input) {",
    "      usage();",
    "      exit(1);",
    "    }",
    "  } else input = stdin;",
    "  /* The default entry point is used. For other options see Parser.H */",
    "  " ++ scope ++ def ++ " *parse_tree = " ++ scope ++ "p" ++ def ++ "(input);",
    "  if (parse_tree)",
    "  {",
    "    printf(\"\\nParse Succesful!\\n\");",
    "    if (!quiet) {",
    "      printf(\"\\n[Abstract Syntax]\\n\");",
    "      " ++ scope ++ "ShowAbsyn *s = new " ++ scope ++ "ShowAbsyn();",
    "      printf(\"%s\\n\\n\", s->show(parse_tree));",
    "      printf(\"[Linearized Tree]\\n\");",
    "      " ++ scope ++ "PrintAbsyn *p = new " ++ scope ++ "PrintAbsyn();",
    "      printf(\"%s\\n\\n\", p->print(parse_tree));",
    "    }",
    "    return 0;",
    "  }",
    "  return 1;",
    "}",
    ""
   ]
  where
   def = show (head (allEntryPoints cf))
   scope = nsScope inPackage

mkHeaderFile inPackage cf cats eps env = unlines
 [
  "#ifndef " ++ hdef,
  "#define " ++ hdef,
  "",
  "#include<vector>",
  "#include<string>",
  "",
  nsStart inPackage,
  concatMap mkForwardDec cats,
  "typedef union",
  "{",
  "  int int_;",
  "  char char_;",
  "  double double_;",
  "  char* string_;",
  concatMap mkVar cats ++ "} YYSTYPE;",
  "",
  concatMap mkFuncs eps,
  nsEnd inPackage,
  "",
  "#define " ++ nsDefine inPackage "_ERROR_" ++ " 258",
  mkDefines (259 :: Int) env,
  "extern " ++ nsScope inPackage ++ "YYSTYPE " ++ nsString inPackage ++ "yylval;",
  "",
  "#endif"
 ]
 where
  hdef = nsDefine inPackage "PARSER_HEADER_FILE"
  mkForwardDec s | normCat s == s = "class " ++ identCat s ++ ";\n"
  mkForwardDec _ = ""
  mkVar s | normCat s == s = "  " ++ identCat s ++"*" +++ map toLower (identCat s) ++ "_;\n"
  mkVar _ = ""
  mkDefines n [] = mkString n
  mkDefines n ((_,s):ss) = "#define " ++ s +++ show n ++ "\n" ++ mkDefines (n+1) ss -- "nsDefine inPackage s" not needed (see cf2flex::makeSymEnv)
  mkString n =  if isUsedCat cf catString
   then ("#define " ++ nsDefine inPackage "_STRING_ " ++ show n ++ "\n") ++ mkChar (n+1)
   else mkChar n
  mkChar n =  if isUsedCat cf catChar
   then ("#define " ++ nsDefine inPackage "_CHAR_ " ++ show n ++ "\n") ++ mkInteger (n+1)
   else mkInteger n
  mkInteger n =  if isUsedCat cf catInteger
   then ("#define " ++ nsDefine inPackage "_INTEGER_ " ++ show n ++ "\n") ++ mkDouble (n+1)
   else mkDouble n
  mkDouble n =  if isUsedCat cf catDouble
   then ("#define " ++ nsDefine inPackage "_DOUBLE_ " ++ show n ++ "\n") ++ mkIdent(n+1)
   else mkIdent n
  mkIdent n =  if isUsedCat cf catIdent
   then "#define " ++ nsDefine inPackage "_IDENT_ " ++ show n ++ "\n"
   else ""
  mkFuncs s | normCat s == s = identCat s ++ "*" +++ "p" ++ identCat s ++ "(FILE *inp);\n" ++
                               identCat s ++ "*" +++ "p" ++ identCat s ++ "(const char *str);\n"
  mkFuncs _ = ""
