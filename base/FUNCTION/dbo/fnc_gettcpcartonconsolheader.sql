SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPCartonConsolHeader] (@nSerialNo INT)    
RETURNS @tCartonConsolHeader TABLE     
(    
    SerialNo         INT PRIMARY KEY NOT NULL,    
    MessageNum       NVARCHAR(8)  NOT NULL,    
    MessageName      NVARCHAR(15) NOT NULL,    
    StorerKey        NVARCHAR(15) NOT NULL,    
    Facility         NVARCHAR( 5) NOT NULL,     
    MasterLPNNo      NVARCHAR(20) NOT NULL,    
    [STATUS]         NVARCHAR(1)  NOT NULL     
)    
AS    
BEGIN    
	-- SELECT ALL DATA
	IF @nSerialNo = 0
	BEGIN
	  INSERT @tCartonConsolHeader  
     SELECT ti.SerialNo,     
            ti.MessageNum,     
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,    
            ISNULL(RTRIM(SubString(ti.[Data],  16,  15)),'') AS StorerKey,    
            ISNULL(RTRIM(SubString(ti.[Data],  31,   5)),'') AS Facility,             
            ISNULL(RTRIM(SubString(ti.[Data],  36,  20)),'') AS MasterLPNNo,  
            ti.[Status]    
     FROM TCPSocket_OUTLog ti WITH (NOLOCK)    
     WHERE (Data Like '%CARTONCONSOL%')   
	END
	ELSE
	BEGIN
	  INSERT @tCartonConsolHeader  
     SELECT ti.SerialNo,     
            ti.MessageNum,     
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,    
            ISNULL(RTRIM(SubString(ti.[Data],  16,  15)),'') AS StorerKey,    
            ISNULL(RTRIM(SubString(ti.[Data],  31,   5)),'') AS Facility,             
            ISNULL(RTRIM(SubString(ti.[Data],  36,  20)),'') AS MasterLPNNo,  
            ti.[Status]    
     FROM TCPSocket_OUTLog ti WITH (NOLOCK)    
     WHERE ti.SerialNo = @nSerialNo     
	END 
   RETURN    
END;

GO