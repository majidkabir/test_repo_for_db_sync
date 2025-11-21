SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION [dbo].[fnc_GetTCPResidualShort] (@nSerialNo INT)  
RETURNS @tResidualShort TABLE   
(  
    SerialNo         INT PRIMARY KEY NOT NULL,  
    MessageNum       NVARCHAR(10) NOT NULL,  
    MessageType      NVARCHAR(15) NOT NULL,  
    StorerKey        NVARCHAR(15) NOT NULL,  
    Facility         NVARCHAR(5)  NOT NULL,  
    TargetLoc        NVARCHAR(10) NOT NULL,  
    SKU              NVARCHAR(20) NOT NULL,  
    QtyExpected      INT         NOT NULL,  
    QtyActual        INT         NOT NULL,              
    ReconcilLoc      NVARCHAR(10) NOT NULL,  
    TransCode        NVARCHAR(10) NOT NULL,  
    ReasonCode       NVARCHAR(10) NOT NULL,  
    [STATUS]         NVARCHAR(1)  NOT NULL   
)  
AS  
BEGIN  
WITH ResidualShort(SerialNo ,MessageNum ,MessageType ,StorerKey ,Facility ,TargetLoc ,SKU ,QtyExpected   
                   ,QtyActual ,ReconcilLoc ,TransCode ,ReasonCode, [STATUS]) -- Table name and columns  
    AS (  
     SELECT ti.SerialNo,   
            ti.MessageNum,   
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageType,  
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,   
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,  
            ISNULL(RTRIM(SubString(ti.[Data],  44,  10)),'') AS TargetLoc,  
            ISNULL(RTRIM(SubString(ti.[Data],  54,  20)),'') AS SKU,  
                          
             CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data],  74,  10))) = 1   
                 THEN CAST(RTRIM(SubString(ti.[Data],  74,  10)) AS INT)   
                 ELSE 0   
            END  AS QtyExpected,  
              
            CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data],  84,  10))) = 1   
                 THEN CAST(RTRIM(SubString(ti.[Data],  84,  10)) AS INT)   
                 ELSE 0   
            END  AS QtyActual,  
            ISNULL(RTRIM(SubString(ti.[Data],  94,  10)),'') AS ReconcilLoc,  
            ISNULL(RTRIM(SubString(ti.[Data], 104,   5)),'') AS TranCode,  
            ISNULL(RTRIM(SubString(ti.[Data], 109,  10)),'') AS ReasonCode,   
            ti.[Status]  
     FROM TCPSocket_INLog ti WITH (NOLOCK)  
     WHERE ti.SerialNo = @nSerialNo   
        )  
-- copy the required columns to the result of the function   
   INSERT @tResidualShort   
   SELECT SerialNo ,MessageNum ,MessageType ,StorerKey ,Facility ,TargetLoc ,SKU ,QtyExpected   
                   ,QtyActual ,ReconcilLoc ,TransCode ,ReasonCode, [STATUS]  
   FROM ResidualShort   
   RETURN  
END;

GO