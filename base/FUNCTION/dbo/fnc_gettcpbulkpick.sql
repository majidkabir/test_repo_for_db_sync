SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPBULKPICK] (@nSerialNo INT)  
RETURNS @tBULKPICK TABLE   
(  
    SerialNo         INT PRIMARY KEY NOT NULL,  
    MessageNum       NVARCHAR(8)  NOT NULL,  
    MessageType      NVARCHAR(15) NOT NULL,  
    StorerKey        NVARCHAR(15) NOT NULL,  
    Facility         NVARCHAR(5)  NOT NULL,  
    LPNNo            NVARCHAR(20) NOT NULL,  
    OrderKey         NVARCHAR(10) NOT NULL,  
    OrderLineNumber  NVARCHAR(5)  NOT NULL,  
    ConsoOrderKey    NVARCHAR(30) NOT NULL,   
    SKU              NVARCHAR(20) NOT NULL,  
    Qty_Expected     INT         NOT NULL,  
    Qty_Actual       INT         NOT NULL,  
    FROMLOC          NVARCHAR(10) NOT NULL,  
    TOLOC            NVARCHAR(10) NOT NULL,  
    TransCode        NVARCHAR(5)  NOT NULL,  
    [STATUS]         NVARCHAR(1)  NOT NULL   
)  
AS  
BEGIN  
WITH BULKPICK(SerialNo, MessageNum, MessageType, StorerKey, Facility, LPNNo, OrderKey, OrderLineNumber,   
                 ConsoOrderKey, SKU, Qty_Expected, Qty_Actual, FROMLOC, TOLOC, TransCode, [STATUS]) -- Table name and columns  
    AS (  
     SELECT ti.SerialNo,   
            ti.MessageNum,   
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,   15)),'') AS MessageType,  
            ISNULL(RTRIM(SubString(ti.[Data],  24,   15)),'') AS StorerKey,   
            ISNULL(RTRIM(SubString(ti.[Data],  39,    5)),'') AS Facility,  
            ISNULL(RTRIM(SubString(ti.[Data],  44,   20)),'') AS LPNNo,              
            ISNULL(RTRIM(SubString(ti.[Data],  64,   10)),'') AS OrderKey,    
            ISNULL(RTRIM(SubString(ti.[Data],  74,    5)),'') AS OrderLineNumber,    
            ISNULL(RTRIM(SubString(ti.[Data],  79,   30)),'') AS ConsoOrderKey,   
            ISNULL(RTRIM(SubString(ti.[Data],  109,  20)),'') AS SKU,  
             CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data],  129,  10))) = 1   
                 THEN CAST(RTRIM(SubString(ti.[Data],  129,  10)) AS INT)   
                 ELSE 0   
            END  AS Qty_Expected,  
             CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data],  139,  10))) = 1   
                 THEN CAST(RTRIM(SubString(ti.[Data],  139,  10)) AS INT)   
                 ELSE 0   
            END  AS Qty_Actual,              
            ISNULL(RTRIM(SubString(ti.[Data], 149,  10)),'') AS FROMLOC,  
            ISNULL(RTRIM(SubString(ti.[Data], 159,  10)),'') AS TOLOC,                          
            ISNULL(RTRIM(SubString(ti.[Data], 169,   5)),'') AS TransCode,   
            ti.[Status]  
     FROM TCPSocket_INLog ti WITH (NOLOCK)  
     WHERE ti.Data LIKE 'ALLOCMOVE%'
        AND ti.SerialNo = CASE WHEN @nSerialNo = 0 THEN ti.SerialNo ELSE @nSerialNo END
        )  
-- copy the required columns to the result of the function   
   INSERT @tBULKPICK   
   SELECT SerialNo, MessageNum, MessageType, StorerKey, Facility, LPNNo, OrderKey, OrderLineNumber,   
          ConsoOrderKey, SKU, Qty_Expected, Qty_Actual, FROMLOC, TOLOC, TransCode, [STATUS]  
   FROM BULKPICK   
   RETURN  
END;

GO