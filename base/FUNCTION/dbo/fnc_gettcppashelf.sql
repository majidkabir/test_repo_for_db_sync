SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: fnc_GetTCPPASHELF			                            */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 05-04-2012   Shong         Adding Filtering                          */
/************************************************************************/
CREATE FUNCTION [dbo].[fnc_GetTCPPASHELF] (@nSerialNo INT)
RETURNS @tPASHELF TABLE 
(
    SerialNo         INT PRIMARY KEY NOT NULL,
    MessageNum       NVARCHAR(8)  NOT NULL,
    MessageType      NVARCHAR(15) NOT NULL,
    StorerKey        NVARCHAR(15) NOT NULL,
    Facility         NVARCHAR(5)  NOT NULL,
    SKU              NVARCHAR(20) NOT NULL,
    Qty_Expected     INT         NOT NULL,
    Qty_Actual       INT         NOT NULL,
    PutawayLOC       NVARCHAR(10) NOT NULL,
    TransCode        NVARCHAR(5)  NOT NULL,
    [STATUS]         NVARCHAR(1)  NOT NULL 
)
AS
BEGIN
WITH PASHELF(SerialNo, MessageNum, MessageType, StorerKey, Facility, SKU, Qty_Expected, 
             Qty_Actual, PutawayLOC, TransCode, [STATUS]) -- Table name and columns
    AS (
    	SELECT ti.SerialNo, 
    	       ti.MessageNum, 
    	       ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageType,
    	       ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey, 
    	       ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,
    	       ISNULL(RTRIM(SubString(ti.[Data],  44,  20)),'') AS SKU,
             CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data], 64,  10))) = 1 
    	            THEN CAST(RTRIM(SubString(ti.[Data], 64,  10)) AS INT) 
    	            ELSE 0 
    	       END  AS Qty_Expected,
             CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data], 74,  10))) = 1 
    	            THEN CAST(RTRIM(SubString(ti.[Data], 74,  10)) AS INT) 
    	            ELSE 0 
    	       END  AS Qty_Actual,    	       
    	       ISNULL(RTRIM(SubString(ti.[Data], 84,  10)),'') AS PutawayLOC,	           	       
    	       ISNULL(RTRIM(SubString(ti.[Data], 94,   5)),'') AS TransCode, 
    	       ti.[Status]
    	FROM TCPSocket_INLog ti WITH (NOLOCK)
    	WHERE ti.Data LIKE 'RESIDUALMV%' 
    	AND ti.SerialNo = CASE WHEN @nSerialNo = 0 THEN ti.SerialNo ELSE @nSerialNo END 
        )
-- copy the required columns to the result of the function 
   INSERT @tPASHELF 
   SELECT SerialNo, MessageNum, MessageType, StorerKey, Facility, SKU, Qty_Expected, 
          Qty_Actual, PutawayLOC, TransCode, [STATUS]
   FROM PASHELF 
   RETURN
END;

GO