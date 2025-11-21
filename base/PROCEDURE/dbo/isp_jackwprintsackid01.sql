SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_JACKWPrintSackID01                             */  
/* Creation Date: 29-Jun-2010                                           */  
/*                                                                      */  
/* Purpose:  Print sack id for jack will uk                             */  
/*                                                                      */  
/* Input Parameters:  @n_NoOfCopy , - no of copy of Sack ID             */  
/*                                                                      */  
/* Called By:  dw = r_dw_storetote_label06                              */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 28-07-2016   James         SOS370236 - Created                       */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_JACKWPrintSackID01] (  
   @cNoOfCopy NVARCHAR( 5)
)   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cSackID    NVARCHAR(10),
           @bSuccess   INT,
           @nErrNo     INT,
           @nContinue  INT,
           @nStarttCnt INT,
           @nNoOfCopy  INT, 
           @cErrMsg    NVARCHAR( 250)

   SET @nNoOfCopy = CAST( @cNoOfCopy AS INT)
   
   SELECT @nContinue = 1, @nStarttCnt = @@TRANCOUNT 

   CREATE TABLE #TEMPLABEL ( SackID	NVARCHAR(10))   

   BEGIN TRAN  

   WHILE @nNoOfCopy > 0
   BEGIN
      EXECUTE nspg_getkey
         @KeyName       = 'IntToteNoRange' ,
         @fieldlength   = 10,    
         @keystring     = @cSackID     OUTPUT,
         @b_success     = @bSuccess    OUTPUT,
         @n_err         = @nErrNo      OUTPUT,
         @c_errmsg      = @cErrMsg     OUTPUT,
         @b_resultset   = 0,
         @n_batch       = 1

      IF @nErrNo <> 0 OR @bSuccess <> 1
      BEGIN  
         SET @nContinue = 3  
         SELECT @cErrMsg = CONVERT(CHAR(250),@nErrNo), @nErrNo = 63104     
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErrNo)+': Insert #TEMPLABEL Failed. ' +   
                         ' (isp_JACKWPrintSackID01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@cErrMsg)) + ' ) '  
         GOTO EXIT_SP  
      END

      INSERT INTO #TEMPLABEL (SackID) VALUES (@cSackID)

      SELECT @nErrNo = @@ERROR  
      IF @nErrNo <> 0  
      BEGIN  
         SELECT @nContinue = 3  
         SELECT @cErrMsg = CONVERT(CHAR(250),@nErrNo), @nErrNo = 63104     
         SELECT @cErrMsg = 'NSQL'+CONVERT(char(5),@nErrNo)+': Insert #TEMPLABEL Failed. ' +   
                            ' (isp_JACKWPrintSackID01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@cErrMsg)) + ' ) '  
         GOTO EXIT_SP  
      END  
      
      SET @nNoOfCopy = @nNoOfCopy - 1
   END

   SELECT SackID FROM #TEMPLABEL ORDER BY 1

   DROP TABLE #TEMPLABEL  
  
   EXIT_SP:   
   IF @nContinue = 3  
   BEGIN  
      WHILE @@TRANCOUNT > @nStarttCnt  
      ROLLBACK TRAN  
      EXECUTE nsp_logerror @nErrNo, @cErrMsg, 'isp_JACKWPrintSackID01'  
      RAISERROR (@cErrMsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      /* Error Did Not Occur , Return Normally */  
      WHILE @@TRANCOUNT > @nStarttCnt  
         COMMIT TRAN  
      RETURN  
   END  
  
END  

GO