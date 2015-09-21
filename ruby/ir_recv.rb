
require 'serialport'
require 'color'
require 'hue'

SERIAL_PORT = ENV['SERIAL_PORT'] || Dir.glob('/dev/cu.*usbserial*').first || raise("can't find serialport")

module ToHSB
  def to_hsb
    hsl = to_hsl
    {
      hue: (hsl.hue * (65536 / 360)).to_i,
      brightness: (hsl.brightness * 255.0).to_i,
      saturation: (hsl.saturation * 2.55).to_i
    }
  end
end

Color::HSL.include(ToHSB)

class IRReceiver
  # IR Remote Controller
  # SONY PLZ530D
  # manufacturing company No: 0607
  # http://www.sony.jp/ServiceArea/impdf/manual/42672000RM-PLZ530D.html

  MAPPING = {
    "DACBA6CF" => 'ch1',
    "E3437029" => 'ch2',
    "FD32024F" => 'ch3',
    "C20FD44D" => 'ch4',
    "D1BDDFBB" => 'ch5',
    "F5C2694D" => 'ch6',
    "101627FB" => 'ch7',
    "B368778E" => 'ch8',
    "6828DB74" => 'ch9',
    "45F61F06" => 'ch10',
    "A95C6BFB" => 'ch11',
    "64953EC7" => 'ch12',
    "506B887"  => 'ch_plus',
    "37B7F8D1" => 'ch_minus',
    "B000B3FB" => 'blue',
    "533DCF5B" => 'red',
    "9311C57B" => 'green',
    "3B9D6723" => 'yellow',
    "FB5BE1FB" => 'power',
  }

  def initialize
    @hue = Hue::Client.new
    @on = false
    @last_power = Time.now
  end

  def lights
    @hue.lights
  end

  def lights_refresh!
    @hue.bridge.instance_eval { @lights = nil }
  end

  def lights_state(state = {}, wait = 4)
    state = {
      on: true,
    }.merge(state)
    puts "lights_state: #{state.inspect}"
    lights.each do |light|
      light.set_state(state, wait)
    end
  end

  def power
    if (Time.now - @last_power) > 0.5
      @last_power = Time.now
      @on = !@on
      lights_state({on: @on}, 1)
    end
  end

  def red
    hsb = Color::RGB.new(255, 0, 0).to_hsl.to_hsb
    lights_state(hsb)
  end

  def green
    hsb = Color::RGB.new(0, 255, 0).to_hsl.to_hsb
    lights_state(hsb)
  end

  def blue
    hsb = Color::RGB.new(0, 0, 255).to_hsl.to_hsb
    lights_state(hsb)
  end

  def yellow
    lights_state({
      hue: 8000,
      brightness: 170,
      saturation: 150,
    })
  end

  HUE_TH = 2000
  def ch1
    # hue++
    lights_refresh!
    hue = lights.first.hue + HUE_TH
    if hue > 65535
      hue = hue - 65535
    end
    lights_state({hue: hue}, 1)
  end

  def ch4
    # hue--
    lights_refresh!
    hue = lights.first.hue - HUE_TH
    if hue < 0
      hue = hue + 65535
    end
    lights_state({hue: hue}, 1)
  end

  BRIGHTNESS_TH = 25
  def ch2
    # brightness++
    lights_refresh!
    brightness = [lights.first.brightness + BRIGHTNESS_TH, 255].min
    lights_state({brightness: brightness}, 1)
  end

  def ch5
    # brightness--
    lights_refresh!
    brightness = [lights.first.brightness - BRIGHTNESS_TH, 1].max
    lights_state({brightness: brightness}, 1)
  end

  SATURATION_TH = 25
  def ch3
    # saturation++
    lights_refresh!
    saturation = [lights.first.saturation + SATURATION_TH, 255].min
    lights_state({saturation: saturation}, 1)
  end

  def ch6
    # saturation++
    lights_refresh!
    saturation = [lights.first.saturation - SATURATION_TH, 1].max
    lights_state({saturation: saturation}, 1)
  end

  def ch10
    # random each light
    lights.each do |light|
      light.set_state({
        on: true,
        hue: rand(65535),
        brightness: rand(255),
        saturation: 127 + rand(128),
      }, 1)
    end
  end

  def ch11
    # random
    lights_state({
      hue: rand(65535),
      brightness: rand(255),
      saturation: 255,
    }, 1)
  end

  def ch12
    # random
    lights_state({
      hue: rand(65535),
      brightness: rand(255),
      saturation: rand(255),
    }, 1)
  end

  def recv(data)
    if name = MAPPING[data]
      puts "recv: #{name} - #{data}"
      if respond_to? name
        puts "- call: #{name}"
        begin
        __send__(name)
        rescue => e
          puts e.message
          puts e.backtrace.join("\n")
        end
      end
    else
      puts "recv: nothing - #{data}"
    end
  end
end

serial = SerialPort.new(SERIAL_PORT, 9600, 8, 1, 0)
receiver = IRReceiver.new

serial.gets # ignore first line
while line = serial.gets
  line.chomp!
  message, data = line.split(',')
  if message == 'IR'
    receiver.recv(data)
  end
end


