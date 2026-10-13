# frozen_string_literal: true

# Polish plural forms: 1 zestaw, 2–4/22–24 zestawy, 0/5–21/12–14 zestawów.
# Fractions (1.5) use :other — "1,5 łyżki". Whole-number floats (2.0) follow the integer rule.
{
  pl: {
    i18n: {
      plural: {
        keys: %i[one few many other],
        rule: lambda do |n|
          return :other unless n == n.to_i

          n = n.to_i
          return :one if n == 1
          return :few if (2..4).cover?(n % 10) && !(12..14).cover?(n % 100)

          :many
        end
      }
    }
  }
}
