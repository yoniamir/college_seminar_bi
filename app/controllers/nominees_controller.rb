#encoding: utf-8

class NomineesController < ApplicationController
  before_filter :require_login, :only => [:new, :show, :create]
  
  def show
    @nominee = Nominee.find(params[:id])
    
    # Generate box results
    @nominee_boxes = []
    query_codes = RegressionFormula.where(school_code: @nominee.school_code).select("distinct query_code, regression_type_code, question, question_code, correlation_coefficient").order('question_code')
    query_codes.each do |f|
      next if f.question_code == 7 # Skip this one. didnt remove in db just in case..
      y = NomineesHelper.calc_formula(@nominee, f.query_code, f.regression_type_code).round(2)
      r = f.correlation_coefficient

      if f.question_code == 3 # משך תואר משוער בשנים
        y_formatted = NomineesHelper.format_degree_duration(y)
      else
        y_formatted = (y * 100).round(2).to_s + "%" if (f.regression_type_code == 9)
      end

      @nominee_boxes << [f.question, y_formatted || y.to_s, r]
    end

    # Generate charts
    @nominee_charts = []
    graph_rows = RegressionGraph.where('school_code = ? AND var_code is not null', @nominee.school_code)
    graph_rows.each do |g|
      chart = Hash.new
      x_axis_field = NomineesHelper::get_display_by_code_regressions("variable", g.var_code)
      x_title = t("views.nominee_show.#{x_axis_field}")
      chart[:tickInterval] = 1 if x_axis_field == 'starting_semester'
      chart[:x_axis] = x_title
      chart[:y_axis] = g.question 
      chart[:title] = chart[:x_axis] + " - " + chart[:y_axis]
      chart[:data_linear] = NomineesHelper.nominee_chart_data_linear(@nominee, g.query_code)
      chart[:data_dots_obs] = NomineesHelper.nominee_chart_data_dots_observations(@nominee.school_code, x_axis_field, NomineesHelper::get_tag_by_code_regressions("question", g.question_code, "y_variable"))
      chart[:data_dots_ind] = NomineesHelper.nominee_chart_data_dots_single(@nominee, g.var_code, g.query_code)
      @nominee_charts << chart
    end
  end

  # GET /nominees/new
  def new
    @nominee = Nominee.new
  end


  # POST /nominees
  # POST /nominees.json
  def create
    Rails.logger.error(params[:nominee])
    @nominee = Nominee.new(params[:nominee])

    # Get lookup values
    @nominee.city = StudentsLookup.where("field_name = 'city' and numeric_value = ? ", @nominee.city_code).first.display_name
    @nominee.gender = StudentsLookup.where("field_name = 'gender' and numeric_value = ? ", @nominee.gender_code).first.display_name
    @nominee.school = StudentsLookup.where("field_name = 'school' and numeric_value = ? ", @nominee.school_code).first.display_name
    
    if @nominee.save
      redirect_to @nominee, notice: 'Nominee was successfully created.'
    else
      render action: "new"
    end
  end

end
