# -*- encoding : utf-8 -*-
# M2 Taxes
class Tax < ActiveRecord::Base
  has_one :user

  attr_protected

  before_save :tax_before_save

  def tax_before_save
    self.total_tax_name = 'TAX' if total_tax_name.blank?
    self.tax1_name = total_tax_name if tax1_name.blank?
  end

  # Returns count of enabled taxes.
  def get_tax_count
    1 + tax2_enabled.to_i + tax3_enabled.to_i + tax4_enabled.to_i
  end

  def sum_tax
    sum = tax1_value.to_d
    sum += tax2_value.to_d if tax2_enabled.to_i == 1
    sum += tax3_value.to_d if tax3_enabled.to_i == 1
    sum += tax4_value.to_d if tax4_enabled.to_i == 1
    sum
  end

  def assign_default_tax(tax = {}, opt = {})
    options = {save: true}.merge(opt)

    if !tax || tax.blank?
      tax = {
          tax1_enabled: 1,
          tax2_enabled: Confline.get_value2('Tax_2', 0).to_i,
          tax3_enabled: Confline.get_value2('Tax_3', 0).to_i,
          tax4_enabled: Confline.get_value2('Tax_4', 0).to_i,
          tax1_name: Confline.get_value('Tax_1', 0),
          tax2_name: Confline.get_value('Tax_2', 0),
          tax3_name: Confline.get_value('Tax_3', 0),
          tax4_name: Confline.get_value('Tax_4', 0),
          total_tax_name: Confline.get_value('Total_tax_name', 0),
          tax1_value: Confline.get_value('Tax_1_Value', 0).to_d,
          tax2_value: Confline.get_value('Tax_2_Value', 0).to_d,
          tax3_value: Confline.get_value('Tax_3_Value', 0).to_d,
          tax4_value: Confline.get_value('Tax_4_Value', 0).to_d,
          compound_tax: Confline.get_value('Tax_compound', 0).to_i
      }
    end

    self.attributes = tax
    self.save if options[:save] == true
  end

 # Calculates amount with taxes applied.
 # Amount - float value representing the amount after taxes have been applied.
  def apply_tax(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    tax2_is_enabled = tax2_enabled.to_i == 1
    tax3_is_enabled = tax3_enabled.to_i == 1
    tax4_is_enabled = tax4_enabled.to_i == 1

    if compound_tax.to_i == 1
      if opts[:precision]
        amount += format("%.#{opts[:precision].to_i}f", (amount * tax1_value / 100.0)).to_d
        amount += format("%.#{opts[:precision].to_i}f", (amount * tax2_value / 100.0)).to_d if tax2_is_enabled
        amount += format("%.#{opts[:precision].to_i}f", (amount * tax3_value / 100.0)).to_d if tax3_is_enabled
        amount += format("%.#{opts[:precision].to_i}f", (amount * tax4_value / 100.0)).to_d if tax4_is_enabled
      else
        amount += (amount * tax1_value / 100.0)
        amount += (amount * tax2_value / 100.0) if tax2_is_enabled
        amount += (amount * tax3_value / 100.0) if tax3_is_enabled
        amount += (amount * tax4_value / 100.0) if tax4_is_enabled
      end
    else
      tax = 0

      if opts[:precision]
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax1_value / 100.0)).to_d
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax2_value / 100.0)).to_d if tax2_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax3_value / 100.0)).to_d if tax3_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax4_value / 100.0)).to_d if tax4_is_enabled
      else
        tax += (amount * tax1_value / 100.0)
        tax += (amount * tax2_value / 100.0) if tax2_is_enabled
        tax += (amount * tax3_value / 100.0) if tax3_is_enabled
        tax += (amount * tax4_value / 100.0) if tax4_is_enabled
      end

      amount += tax
    end

    amount
  end

=begin rdoc
 Calculates amount of tax to be appliet do given amount.

 *Params*

 +amount+

 *Returns*

 +amount+ - float value representing the tax.
=end

  def count_tax_amount(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    tax = amount
    tax2_is_enabled = tax2_enabled.to_i == 1
    tax3_is_enabled = tax3_enabled.to_i == 1
    tax4_is_enabled = tax4_enabled.to_i == 1


    if compound_tax.to_i == 1
      if opts[:precision]
        tax += format("%.#{opts[:precision].to_i}f", (tax * tax1_value / 100.0)).to_d
        tax += format("%.#{opts[:precision].to_i}f", (tax * tax2_value / 100.0)).to_d if tax2_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (tax * tax3_value / 100.0)).to_d if tax3_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (tax * tax4_value / 100.0)).to_d if tax4_is_enabled
      else
        tax += (tax * tax1_value / 100.0)
        tax += (tax * tax2_value / 100.0) if tax2_is_enable d
        tax +=  ( tax  *  tax3_value / 100.0) if tax3_is_enabled
        tax += (tax * tax4_value / 100.0) if tax4_is_enabled
      end
      return tax - amount
    else
      if opts[:precision]
        tax = format("%.#{opts[:precision].to_i}f", (amount * tax1_value / 100.0)).to_d
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax2_value / 100.0)).to_d if tax2_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax3_value / 100.0)).to_d if tax3_is_enabled
        tax += format("%.#{opts[:precision].to_i}f", (amount * tax4_value / 100.0)).to_d if tax4_is_enabled
      else
        tax = amount * tax1_value / 100.0
        tax += (amount * tax2_value / 100.0) if tax2_is_enabled
        tax += (amount * tax3_value / 100.0) if tax3_is_enabled
        tax += (amount * tax4_value / 100.0) if tax4_is_enabled
      end
      return tax
    end
  end

=begin rdoc
 Calculates amount after applying all taxes in tax object.

 *Params*

 +amount+ - amount with vat.

 *Returns*

 +amount+ - float value representing the amount with taxes substracted.
=end
  def count_amount_without_tax(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    tax2_is_enabled = tax2_enabled.to_i == 1
    tax3_is_enabled = tax3_enabled.to_i == 1
    tax4_is_enabled = tax4_enabled.to_i == 1


    if compound_tax.to_i == 1
      if opts[:precision]
        amount = format("%.#{opts[:precision].to_i}f", (amount / (tax4_value.to_d + 100) * 100)).to_d if tax4_is_enabled
        amount = format("%.#{opts[:precision].to_i}f", (amount / (tax3_value.to_d + 100) * 100)).to_d if tax3_is_enabled
        amount = format("%.#{opts[:precision].to_i}f", (amount / (tax2_value.to_d + 100) * 100)).to_d if tax2_is_enabled
        amount = format("%.#{opts[:precision].to_i}f", (amount / (tax1_value.to_d + 100) * 100)).to_d
      else
        amount = (amount / (tax4_value.to_d + 100) * 100) if tax4_is_enabled
        amount = (amount / (tax3_value.to_d + 100) * 100) if tax3_is_enabled
        amount = (amount / (tax2_value.to_d + 100) * 100) if tax2_is_enabled
        amount = (amount / (tax1_value.to_d + 100) * 100)
      end
    else
      amount = amount.to_d / ((sum_tax.to_d / 100.0) + 1.0).to_d
      amount = format("%.#{opts[:precision].to_i}f", amount) if opts[:precision]
    end

    amount
  end

  # Returns list with taxes applied to given amount.
  def applied_tax_list(amount, options = {})
    opts = {}.merge(options)
    amount = amount.to_d
    list = []
    tax2_is_enabled = tax2_enabled.to_i == 1
    tax3_is_enabled = tax3_enabled.to_i == 1
    tax4_is_enabled = tax4_enabled.to_i == 1


    if compound_tax.to_i == 1
      if opts[:precision]
        list << {name: tax1_name.to_s, value: tax1_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax1_value).to_d / 100.0), amount: amount += format("%.#{opts[:precision].to_i}f", (amount * tax1_value).to_d / 100.0).to_d}
        list << {name: tax2_name.to_s, value: tax2_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax2_value).to_d / 100.0), amount: amount += format("%.#{opts[:precision].to_i}f", (amount * tax2_value).to_d / 100.0).to_d} if tax2_is_enabled
        list << {name: tax3_name.to_s, value: tax3_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax3_value).to_d / 100.0), amount: amount += format("%.#{opts[:precision].to_i}f", (amount * tax3_value).to_d / 100.0).to_d} if tax3_is_enabled
        list << {name: tax4_name.to_s, value: tax4_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax4_value).to_d / 100.0), amount: amount += format("%.#{opts[:precision].to_i}f", (amount * tax4_value).to_d / 100.0).to_d} if tax4_is_enabled
      else
        list << {name: tax1_name.to_s, value: tax1_value.to_d, tax: amount * tax1_value / 100.0, amount: amount += amount * tax1_value / 100.0}
        list << {name: tax2_name.to_s, value: tax2_value.to_d, tax: amount * tax2_value / 100.0, amount: amount += amount * tax2_value / 100.0} if tax2_is_enabled
        list << {name: tax3_name.to_s, value: tax3_value.to_d, tax: amount * tax3_value / 100.0, amount: amount += amount * tax3_value / 100.0} if tax3_is_enabled
        list << {name: tax4_name.to_s, value: tax4_value.to_d, tax: amount * tax4_value / 100.0, amount: amount += amount * tax4_value / 100.0} if tax4_is_enabled
      end
    else
      if opts[:precision]
        list << {name: tax1_name.to_s, value: tax1_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax1_value).to_d / 100.0), amount: format("%.#{opts[:precision].to_i}f", (amount * tax1_value).to_d / 100.0).to_d}
        list << {name: tax2_name.to_s, value: tax2_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax2_value).to_d / 100.0), amount: format("%.#{opts[:precision].to_i}f", (amount * tax2_value).to_d / 100.0).to_d} if tax2_is_enabled
        list << {name: tax3_name.to_s, value: tax3_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax3_value).to_d / 100.0), amount: format("%.#{opts[:precision].to_i}f", (amount * tax3_value).to_d / 100.0).to_d} if tax3_is_enabled
        list << {name: tax4_name.to_s, value: tax4_value.to_d, tax: format("%.#{opts[:precision].to_i}f", (amount * tax4_value).to_d / 100.0), amount: format("%.#{opts[:precision].to_i}f", (amount * tax4_value).to_d / 100.0).to_d} if tax4_is_enabled
      else
        list << {name: tax1_name.to_s, value: tax1_value.to_d, tax: amount * tax1_value / 100.0, amount: amount * tax1_value / 100.0}
        list << {name: tax2_name.to_s, value: tax2_value.to_d, tax: amount * tax2_value / 100.0, amount: amount * tax2_value / 100.0} if tax2_is_enabled
        list << {name: tax3_name.to_s, value: tax3_value.to_d, tax: amount * tax3_value / 100.0, amount: amount * tax3_value / 100.0} if tax3_is_enabled
        list << {name: tax4_name.to_s, value: tax4_value.to_d, tax: amount * tax4_value / 100.0, amount: amount * tax4_value / 100.0} if tax4_is_enabled
      end
    end

    list
  end
end

