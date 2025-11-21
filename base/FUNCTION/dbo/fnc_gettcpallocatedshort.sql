SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE FUNCTION dbo.fnc_GetTCPAllocatedShort (@nSerialNo INT)  
RETURNS @tAllocatedShort TABLE   
(  
    SerialNo         int primary key NOT NULL,  
    MessageNum       NVARCHAR(10) NOT NULL,  
    MessageType      NVARCHAR(15) NOT NULL,  
    StorerKey        NVARCHAR(15) NOT NULL,  
    Facility         NVARCHAR(5)  NOT NULL,  
    OrderKey         NVARCHAR(10) NOT NULL,  
    OrderLineNumber  NVARCHAR(5)  NOT NULL,  
    ConsoOrderKey    NVARCHAR(30) NOT NULL,  
    TargetLoc        NVARCHAR(10) NOT NULL,  
    SKU              NVARCHAR(20) NOT NULL,  
    QtyShorted       INT         NOT NULL,  
    TransCode        NVARCHAR(10) NOT NULL,  
    ReasonCode       NVARCHAR(10) NOT NULL,  
    [STATUS]         NVARCHAR(1)  NOT NULL   
)  
AS  
BEGIN  
WITH AllocatedShort(SerialNo ,MessageNum ,MessageType ,StorerKey ,Facility ,OrderKey ,OrderLineNumber ,ConsoOrderKey   
                   ,TargetLoc ,SKU ,QtyShorted ,TransCode ,ReasonCode, STATUS) -- Table name and columns  
    AS (  
     SELECT ti.SerialNo,   
            ti.MessageNum,   
            ISNULL(RTRIM(SUBSTRING(ti.[Data],   1,  15)),'') AS MessageType,  
            ISNULL(RTRIM(SubString(ti.[Data],  24,  15)),'') AS StorerKey,   
            ISNULL(RTRIM(SubString(ti.[Data],  39,   5)),'') AS Facility,  
            ISNULL(RTRIM(SubString(ti.[Data],  44,  10)),'') AS OrderKey,  
            ISNULL(RTRIM(SubString(ti.[Data],  54,   5)),'') AS OrderLineNumber,  
            ISNULL(RTRIM(SubString(ti.[Data],  59,  30)),'') AS ConsoOrderKey,  
            ISNULL(RTRIM(SubString(ti.[Data],  89,  10)),'') AS TargetLoc,  
            ISNULL(RTRIM(SubString(ti.[Data],  99,  20)),'') AS SKU,  
            CASE WHEN ISNUMERIC(RTRIM(SubString(ti.[Data],  119,  10))) = 1   
                 THEN CAST(RTRIM(SubString(ti.[Data],  119,  10)) AS INT)   
                 ELSE 0   
            END  AS QtyShorted,  
            ISNULL(RTRIM(SubString(ti.[Data], 129,  10)),'') AS TranCode,  
            ISNULL(RTRIM(SubString(ti.[Data], 139,  10)),'') AS ReasonCode,   
            ti.[Status]  
     FROM TCPSocket_INLog ti WITH (NOLOCK)  
     WHERE ti.SerialNo = @nSerialNo   
        )  
-- copy the required columns to the result of the function   
   INSERT @tAllocatedShort   
   SELECT SerialNo ,MessageNum ,MessageType ,StorerKey ,Facility ,OrderKey ,OrderLineNumber ,ConsoOrderKey   
                   ,TargetLoc ,SKU ,QtyShorted ,TransCode ,ReasonCode, Status  
   FROM AllocatedShort   
   RETURN  
END;

GO