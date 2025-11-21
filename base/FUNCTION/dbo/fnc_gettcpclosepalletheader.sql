SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPClosePalletHeader] (@nSerialNo INT)      
RETURNS @tClosePalletHeader TABLE       
(      
    SerialNo         INT PRIMARY KEY NOT NULL,      
    MessageNum       NVARCHAR(8)  NOT NULL,      
    MessageName      NVARCHAR(15) NOT NULL,      
    StorerKey        NVARCHAR(15) NOT NULL,      
    Facility         NVARCHAR( 5) NOT NULL,      
    LPNNo            NVARCHAR(18) NOT NULL,      
    LaneNumber       NVARCHAR(10) NOT NULL,      
    [STATUS]         NVARCHAR(1)  NOT NULL       
)      
AS      
BEGIN
	-- SELECT ALL DATA
	IF @nSerialNo = 0
	BEGIN
	  INSERT @tClosePalletHeader  
     SELECT ti.SerialNo,       
            ti.MessageNum,       
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,      
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,      
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,            
            ISNULL(RTRIM(SubString(ti.[Data],  44,  18)),'') AS LPNNo,        
            ISNULL(RTRIM(SubString(ti.[Data],  62,  10)),'') AS LaneNumber,    
            ti.[Status]      
     FROM TCPSocket_INLog ti WITH (NOLOCK)         
     WHERE (Data Like '%CLOSEPALLET%')   
	END
	ELSE
	BEGIN
	  INSERT @tClosePalletHeader  
     SELECT ti.SerialNo,       
            ti.MessageNum,       
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageName,      
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,      
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,            
            ISNULL(RTRIM(SubString(ti.[Data],  44,  18)),'') AS LPNNo,        
            ISNULL(RTRIM(SubString(ti.[Data],  62,  10)),'') AS LaneNumber,    
            ti.[Status]      
     FROM TCPSocket_INLog ti WITH (NOLOCK)      
     WHERE ti.SerialNo = @nSerialNo   
	END 
   RETURN      
END;

GO