import yaml
import json
from ansible import errors

def dictToPS(d):
    """ Formats a Python dictionary as a Powershell hastable. """
    def fmt(v):
        if isinstance(v, dict):
            return dictToPS(v)
        else:
			if isinstance(v, list):
				return listToPS(v)
			else:
				if isinstance(v, unicode):
					return "'{}'".format(v)
				else:
					if isinstance(v,bool):
						return "'{}'".format(v)
					else:
						return repr(v)
				
    return "@{{{}}}".format(";".join("'{}'={}".format(k, fmt(v))
        for k, v in d.iteritems()))


def listToPS(d):
	""" Formats a pyhton list to a powershell array """
	def fmt(v):
		if isinstance(v,unicode):
			return "'{}'".format(v)
		else:
			return repr(v)
			
	return "@({})".format(",".join(format(fmt(k))
		for k in d))
	

def dictToJson(d):
	""" Formats a Python disctionary as a JSON string. """
	def getStringWithDecodedUnicode( value ):
		findUnicodeRE = re.compile( '\\\\u([\da-f]{4})' )
		def getParsedUnicode(x):
			return chr( int( x.group(1), 16 ) )

		return  findUnicodeRE.sub(getParsedUnicode, str( value ) )

	jsonString = json.dumps(d)
	return "\\\'{}\\\'".format(GetStringWithDecodedUnicode(jsonString)) 
		
		
class FilterModule(object):
    ''' Ansible powershell jinja2 filters '''

    def filters(self):
        return {
            # convert yaml array to powershell hash
			'dictToPS' : dictToPS,
			'listToPS' : listToPS,
			'dictToJson' : json.dumps,
		}