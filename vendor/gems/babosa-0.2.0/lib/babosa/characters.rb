# encoding: utf-8
module Babosa

  # This module provides sets of characters needed for various UTF-8 aware
  # string operations.
  module Characters
    extend self

    # Hash of UTF-8 - ASCII approximations.
    attr_reader :approximations
    # Punctuation and control characters to remove from slug strings.
    attr_reader :strippable

    @strippable = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 14, 15, 16, 17, 18, 19,
      20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35, 36, 37, 38, 39,
      40, 41, 42, 43, 44, 45, 46, 47, 58, 59, 60, 61, 62, 63, 64, 91, 92, 93, 94,
      95, 96, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135,
      136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150,
      151, 152, 153, 154, 155, 156, 157, 158, 159, 161, 162, 163, 164, 165, 166,
      167, 168, 169, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 182, 183,
      184, 185, 187, 188, 189, 190, 191, 215, 247]

    # Adds a hash of approximations.
    # @example
    #     add_approximations :spanish, "ñ" => "ni"
    # @param [#to_sym] name The name of the approximations to add.
    # @param Hash hash The approximations to add.
    def add_approximations(name, hash)
      approximations = @approximations ? @approximations.dup : {}
      approximations[name.to_sym] = hash.inject({}) do |memo, object|
        key = object[0].unpack("U").shift
        value = object[1].unpack("C*")
        memo[key] = value.length == 1 ? value[0] : value
        memo
      end.freeze
      @approximations = approximations.freeze
    end

    add_approximations :danish,  "æ" => "ae", "ø" => "oe", "å" => "aa", "Ø" => "Oe", "Å" => "Aa"
    add_approximations :german,  "ä" => "ae", "ö" => "oe", "ü" => "ue", "Ä" => "Ae", "Ö" => "Oe", "Ü" => "Ue"
    add_approximations :serbian, "Ð" => "Dj", "đ" => "dj" ,"Č" => "Ch", "č" => "ch", "Š" => "Sh", "š" => "sh"
    add_approximations :spanish, "ñ" => "ni", "Ñ" => "Ni"
    add_approximations :latin, {
      "À" => "A", "Á" => "A", "Â" => "A", "Ã" => "A", "Ä" => "A", "Å" => "A",
      "Æ" => "Ae", "Ç" => "C", "È" => "E", "É" => "E", "Ê" => "E", "Ë" => "E",
      "Ì" => "I", "Í" => "I", "Î" => "I", "Ï" => "I", "Ð" => "D", "Ñ" => "N",
      "Ò" => "O", "Ó" => "O", "Ô" => "O", "Õ" => "O", "Ö" => "O", "Ø" => "O",
      "Ù" => "U", "Ú" => "U", "Û" => "U", "Ü" => "U", "Ý" => "Y", "Þ" => "Th",
      "ß" => "ss", "à" => "a" , "á" => "a", "â" => "a", "ã" => "a", "ä" => "a",
      "å" => "a", "æ" => "ae", "ç" => "c" , "è" => "e", "é" => "e", "ê" => "e",
      "ë" => "e", "ì" => "i", "í" => "i", "î" => "i", "ï" => "i", "ð" => "d",
      "ñ" => "n", "ò" => "o", "ó" => "o", "ô" => "o", "õ" => "o", "ö" => "o",
      "ø" => "o", "ù" => "u", "ú" => "u", "û" => "u", "ü" => "u", "ý" => "y",
      "þ" => "th", "ÿ" => "y", "Ā" => "A", "ā" => "a", "Ă" => "A", "ă" => "a",
      "Ą" => "A", "ą" => "a", "Ć" => "C", "ć" => "c", "Ĉ" => "C", "ĉ" => "c",
      "Ċ" => "C", "ċ" => "c", "Č" => "C", "č" => "c", "Ď" => "D", "ď" => "d",
      "Đ" => "D", "đ" => "d", "Ē" => "E", "ē" => "e", "Ĕ" => "E", "ĕ" => "e",
      "Ė" => "E", "ė" => "e", "Ę" => "E", "ę" => "e", "Ě" => "E", "ě" => "e",
      "Ĝ" => "G", "ĝ" => "g", "Ğ" => "G", "ğ" => "g", "Ġ" => "G", "ġ" => "g",
      "Ģ" => "G", "ģ" => "g", "Ĥ" => "H", "ĥ" => "h", "Ħ" => "H", "ħ" => "h",
      "Ĩ" => "I", "ĩ" => "i", "Ī" => "I", "ī" => "i", "Ĭ" => "I", "ĭ" => "i",
      "Į" => "I", "į" => "i", "İ" => "I", "ı" => "i", "Ĳ" => "Ij", "ĳ" => "ij",
      "Ĵ" => "J", "ĵ" => "j", "Ķ" => "K", "ķ" => "k", "ĸ" => "k", "Ĺ" => "L",
      "ĺ" => "l", "Ļ" => "L", "ļ" => "l", "Ľ" => "L", "ľ" => "l", "Ŀ" => "L",
      "ŀ" => "l", "Ł" => "L", "ł" => "l", "Ń" => "N", "ń" => "n", "Ņ" => "N",
      "ņ" => "n", "Ň" => "N", "ň" => "n", "ŉ" => "n", "Ŋ" => "Ng", "ŋ" => "ng",
      "Ō" => "O", "ō" => "o", "Ŏ" => "O", "ŏ" => "o", "Ő" => "O", "ő" => "o",
      "Œ" => "OE", "œ" => "oe", "Ŕ" => "R", "ŕ" => "r", "Ŗ" => "R", "ŗ" => "r",
      "Ř" => "R", "ř" => "r", "Ś" => "S", "ś" => "s", "Ŝ" => "S", "ŝ" => "s",
      "Ş" => "S", "ş" => "s", "Š" => "S", "š" => "s", "Ţ" => "T", "ţ" => "t",
      "Ť" => "T", "ť" => "t", "Ŧ" => "T", "ŧ" => "t", "Ũ" => "U", "ũ" => "u",
      "Ū" => "U", "ū" => "u", "Ŭ" => "U", "ŭ" => "u", "Ů" => "U", "ů" => "u",
      "Ű" => "U", "ű" => "u", "Ų" => "U", "ų" => "u", "Ŵ" => "W", "ŵ" => "w",
      "Ŷ" => "Y", "ŷ" => "y", "Ÿ" => "Y", "Ź" => "Z", "ź" => "z", "Ż" => "Z",
      "ż" => "z", "Ž" => "Z", "ž" => "z", "×" => "x", "÷" => "/"
    }
  end
end
