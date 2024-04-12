module IB
  module ConnectionTools
		# Handy method to ensure that a connection is established and active.
		#
		# The connection is reset on the IB-side at least once a day. Then the
		# IB-Ruby-Connection has to be reestablished, too.
		#
		# check_connection reconnects if necessary and returns false if the connection is lost.
		#
		# It delays the process by 6 ms (150 MBit Cable connection)
		#
		#  a =  Time.now; G.check_connection; b= Time.now ;b-a
		#   => 0.00066005
		#
		def check_connection
      q =  Queue.new
      count = 0
      result = nil
      z= subscribe( :CurrentTime ) { q.push true }
			loop do
				begin
					send_message(:RequestCurrentTime)												# 10 ms  ##
          th = Thread.new{ sleep 1 ; q.push nil }
          result =  q.pop
          count+=1
          break if result || count > 10
				rescue IOError, Errno::ECONNREFUSED   # connection lost
					count +=1
          retry
				rescue IB::Error # not connected
					disconnect
          logger.info{"not connected ... trying to reconnect "}
          sleep 0.1
          connect
					count = 0
					retry
				end
			end
			unsubscribe z
			result #  return value
		end

    # Alternative to `Connection#connect'.
    #
    # Trys to connect to the api. If the connection could not be established, waits
    # 10 sec. or one minute and reconnects.
    #
    # Unsuccessful connecting attemps are logged.
    #
    #
    def safe_connect maximal_count_of_retry=100

      i= -1
      begin
        connect
      rescue  Errno::ECONNREFUSED => e
        i+=1
        if i < maximal_count_of_retry
          if i.zero?
            logger.info 'No TWS!'
          else
            logger.info {"No TWS        Retry #{i}/ #{maximal_count_of_retry} " }
          end
          sleep i<50 ? 10 : 60   # Die ersten 50 Versuche im 10 Sekunden Abstand, danach 1 Min.
          retry
        else
          logger.info { "Giving up!!"  }
          return false
        end
      rescue Errno::EHOSTUNREACH => e
        error "Cannot connect to specified host  #{e}", :reader, true
        return false
      rescue SocketError => e
        error 'Wrong Adress, connection not possible', :reader, true
        return false
      rescue IB::Error => e
        logger.info e
      end
      true #  return success-flag
    end # def
  end

  class Connection
    include ConnectionTools
  end
end
