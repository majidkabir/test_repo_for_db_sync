SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/  
/* DB: KRWMS                                                                  */  
/* Purpose: User need to reopen finalized receipt through LogiReport          */  
/* Requester: KR DC3 James                                                    */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date       Rev  Author     Purposes                                        */  
/* 2022-09-06 1.0  Jio        Created                                         */  
/* 2022-09-15 1.0  JAREKLIM   Created https://jiralfl.atlassian.net/browse/WMS-20730 */  
/******************************************************************************/  
CREATE     PROCEDURE [BI].[isp_HMOpenReceiptStatus] (  
    @cReceiptKey    NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;    
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON  
 --DECLARE VARIABLES    
 DECLARE @MSG    NVARCHAR(100) = 'UNKNOWN ERROR OCCURED.'  
  
    --IF FOUND WRONG RECEIPTKEY, RETURN PROCEDURE    
    IF NOT EXISTS (  
        SELECT 1  
          FROM RECEIPT WITH (NOLOCK)  
         WHERE STORERKEY = 'HM'  
           AND RECEIPTKEY = @cReceiptKey  
           AND STATUS NOT IN ('CANC','9')
        )  
    BEGIN  
        SET @MSG = 'INVALID ASN#: THE ASN IS FULLY RECEIVED ALREADY OR CANCLED OR DOES NOT EXIST.'  
    END  
    ELSE
    BEGIN
        BEGIN TRAN  
          
        --OPEN ASNSTATUS    
        UPDATE RECEIPT  
           SET ASNSTATUS = '0'  
         WHERE STORERKEY = 'HM'  
           AND RECEIPTKEY = @cReceiptKey  
          
        DELETE  
          FROM TRANSMITLOG2  
         WHERE KEY3 = 'HM'  
           AND KEY1 = @cReceiptKey  
          
        DELETE  
          FROM TRANSMITLOG3  
         WHERE KEY3 = 'HM'  
           AND KEY1 = @cReceiptKey  
          
        SET @MSG = 'ASN#: '+ @cReceiptKey + ' IS OPEN.'  
            
        IF @@ERROR <> 0  
        BEGIN  
            ROLLBACK TRAN  
            SET @MSG = 'AN ERROR OCCURED WHILE TRYING TO OPEN ASNSTATUS.'  
        END  
          
        COMMIT TRAN  
    END

    SELECT @cReceiptKey AS ReceiptKey, @MSG AS ResultMessage

END  

GRANT EXECUTE ON [BI].[isp_HMOpenReceiptStatus] TO JReportRole

GO