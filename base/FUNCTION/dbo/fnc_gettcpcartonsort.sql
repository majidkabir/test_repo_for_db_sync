SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPCartonSort] (@nSerialNo INT)  
RETURNS @tCartonSort TABLE   
(  
    SerialNo         INT PRIMARY KEY NOT NULL,  
    MessageNum       NVARCHAR(8)  NOT NULL,  
    MessageType      NVARCHAR(15) NOT NULL,  
    LaneNumber       NVARCHAR(10) NOT NULL,  
    SequenceNumber   NVARCHAR(10) NOT NULL,  
    GS1Label         NVARCHAR(20) NOT NULL,  
    Weight           NVARCHAR(8)  NOT NULL,  
    [STATUS]         NVARCHAR(1)  NOT NULL   
)  
AS  
BEGIN  
WITH CartonSort(SerialNo, MessageNum, MessageType, LaneNumber, SequenceNumber, GS1Label, Weight, [STATUS]) -- Table name and columns  
    AS (  
     SELECT ti.SerialNo,   
            ti.MessageNum,   
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageType,  
            ISNULL(RTRIM(SubString(ti.[Data],  24,  10)),'') AS LaneNumber,  
            ISNULL(RTRIM(SubString(ti.[Data],  34,  10)),'') AS SequenceNumber,              
            ISNULL(RTRIM(SubString(ti.[Data],  44,  20)),'') AS GS1Label,    
            ISNULL(RTRIM(SubString(ti.[Data],  64,   8)),'') AS Weight,   
            ti.[Status]  
     FROM TCPSocket_INLog ti WITH (NOLOCK)  
     WHERE ti.SerialNo = @nSerialNo   
        )  
-- copy the required columns to the result of the function   
   INSERT @tCartonSort   
   SELECT SerialNo, MessageNum, MessageType, LaneNumber, SequenceNumber, GS1Label, Weight, [STATUS]  
   FROM CartonSort   
   RETURN  
END;

GO