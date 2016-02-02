require './ml_active_function'
require './ml_active_method'

DEFAULT_RANDOM_MAX = 0.5
DEFAULT_RANDOM_MIN = -0.5

class MLDelta
  @@sharedDelta = MLDelta.new
  attr_accessor :patterns
  attr_accessor :weights
  attr_accessor :targets
  attr_accessor :learningRate
  attr_accessor :maxIteration
  attr_accessor :convergenceValue
  attr_accessor :activeMethod

  attr_accessor :iterationBlock
  attr_accessor :completionBlock

  def initialize
    @active_function = MLActiveFunction.new
    @iteration       = 0
    @sum_error        = 0.0

    @patterns         = []
    @weights          = []
    @targets          = []
    @learningRate     = 0.5
    @maxIteration     = 1
    @convergenceValue = 0.001
    @activeMethod     = MLActiveMethod::TANH

    @iterationBlock   = nil
    @completionBlock  = nil
  end

  # Public methods
  public

  def self.sharedDelta
    return @@sharedDelta
  end

  def addPatterns(_inputs, _target)
    @patterns.push(_inputs)
    @targets.push(_target)
  end

  def setupWeights(_weights)
    if @weights.count > 0
      @weights.clear()
    end
    @weights += _weights
  end

  def randomWeights()
    if @weights.count > 0
      @weights.clear()
    end
    # Follows the inputs count to decide how many weights it needs.
    _randomMaker   = Random.new
    _inputNetCount = @patterns.first().count
    _inputMax      = DEFAULT_RANDOM_MAX / _inputNetCount
    _inputMin      = DEFAULT_RANDOM_MIN / _inputNetCount
    for i in (0..._inputNetCount)
      @weights.push(_randomMaker.rand(_inputMin.._inputMax))
    end
  end

  def training()
    @iteration += 1
    @sum_error   = 0.0
    @patterns.each_with_index{ |inputs, patternIndex| _turningWeightsWithInputs(inputs, @targets[patternIndex]) }
    if (@iteration >= @maxIteration) || (_calculateIterationError() <= @convergenceValue)
      if !@completionBlock.nil?
        @completionBlock.call( true, @weights, @iteration )
      end
    else
      if !@iterationBlock.nil?
        @iterationBlock.call( @iteration, @weights )
      end
      training()
    end
  end

  def trainingWithCompletion(&_block)
    @completionBlock = _block
    training()
  end

  def trainingWithIteration(_iterationBlock, _completionBlock)
    @iterationBlock  = _iterationBlock
    @completionBlock = _completionBlock
    training()
  end

  def directOutputByPatterns(_inputs, &_block)
    _netOutput = _fOfNetWithInputs(_inputs)
    if block_given?
      _block.call(_netOutput)
    end
  end

  # Private methods
  private

  def _multiplyMatrix(_matrix, _number)
    return _matrix.map{ |obj| obj * _number }
  end

  def _plusMatrix(_matrix, _anotherMatrix)
    return _matrix.collect.with_index{ |obj, i| obj + _anotherMatrix[i] }
  end

  def _activateOutputValue(_netOutput)
    _activatedValue = _netOutput
    case @activeMethod
      when MLActiveMethod::SGN
        _activatedValue = @active_function.sgn(_netOutput)
      when MLActiveMethod::SIGMOID
        _activatedValue = @active_function.sigmoid(_netOutput)
      when MLActiveMethod::TANH
        _activatedValue = @active_function.tanh(_netOutput)
      when MLActiveMethod::RBF
        _activatedValue = @active_function.rbf(_netOutput, 2.0)
      else
        # Nothing else
    end
    return _activatedValue
  end

  def _fOfNetWithInputs(_inputs)
    # to_f
    _sum = 0.0
    _inputs.each.with_index{ |obj, i| _sum += ( obj * @weights[i] ) }
    return _activateOutputValue(_sum)
  end

  def _fDashOfNet(_netOutput)
    _dashValue = _netOutput
    case @activeMethod
      when MLActiveMethod::SGN
        _dashValue = @active_function.dashSgn(_netOutput)
      when MLActiveMethod::SIGMOID
        _dashValue = @active_function.dashSigmoid(_netOutput)
      when MLActiveMethod::TANH
        _dashValue = @active_function.dashTanh(_netOutput)
      when MLActiveMethod::RBF
        #_dashValue = @active_function.dashRbf(_netOutput)
      else
        # Nothing else
    end
    return _dashValue
  end

  # Delta defined cost function formula
  def _calculateIterationError()
    return (@sum_error / @patterns.count()) * 0.5
  end

  def sum_error(_errorValue)
    @sum_error   += (_errorValue * _errorValue)
  end

  def _turningWeightsWithInputs(_inputs, _targetValue)
    _weights      = @weights
    _learningRate = @learningRate
    _netOutput    = _fOfNetWithInputs(_inputs)
    _dashOutput   = _fDashOfNet(_netOutput)
    _errorValue   = _targetValue - _netOutput

    # new weights = learning rate * (target value - net output) * f'(net) * x1 + w1
    _sigmaValue   = _learningRate * _errorValue * _dashOutput
    _deltaWeights = _multiplyMatrix(_inputs, _sigmaValue)
    _newWeights   = _plusMatrix(_weights, _deltaWeights)

    @weights.clear()
    @weights += _newWeights
    sum_error(_errorValue)
  end

end

# Use methods
delta                  = MLDelta.new
delta.activeMethod     = MLActiveMethod::TANH
delta.learningRate     = 0.8
delta.convergenceValue = 0.001
delta.maxIteration     = 1000
delta.addPatterns([1.0, -2.0, 0.0, -1.0], -1.0)
delta.addPatterns([0.0, 1.5, -0.5, -1.0], 1.0)
delta.setupWeights([1.0, -1.0, 0.0, 0.5])
#delta.randomWeights()

iterationBlock = Proc.new do |iteration, weights|
  puts "iteration : #{iteration}, weights : #{weights}"
end

completionBlock = Proc.new do |success, weights, totalIteration|
  puts "success : #{success}, weights : #{weights}, totalIteration : #{totalIteration}"
  delta.directOutputByPatterns([1.0, -2.0, 0.0, -1.0]){ |predication| puts "predication result is #{predication}" }
end

delta.trainingWithIteration(iterationBlock, completionBlock)

# delta.trainingWithCompletion {
#   |success, weights, totalIteration|
#   puts "success : #{success}, weights : #{weights}, totalIteration : #{totalIteration}"
# }
