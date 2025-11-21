SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Exec_LabelGenCode                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: SHONG                                                    */
/*                                                                      */
/* Purpose: SOS166181                                                   */
/*                                                                      */
/* Called By: WMS Pick & Pack Module                                    */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_Exec_LabelGenCode]
   @cLabelGenCode NVARCHAR(30),
   @cPickSlipNo NVARCHAR(10),
   @nCartonNo INT=0,
   @cNewLabelNo NVARCHAR(20)='' OUTPUT,
   @nErrNo INT=0 OUTPUT,
   @cErrMsg NVARCHAR(215)='' OUTPUT 
AS
BEGIN
    SET NOCOUNT ON
    SET ANSI_DEFAULTS OFF  
    SET QUOTED_IDENTIFIER OFF
    SET CONCAT_NULL_YIELDS_NULL OFF
    
    DECLARE @nContinue   INT
           ,@nCnt        INT
           ,@nTrancount  INT
           ,@cSQL         NVARCHAR(MAX)
    
   IF ISNULL(RTRIM(@cLabelGenCode),'') = ''
   BEGIN
      SET @cNewLabelNo = ''
      GOTO EXIT_PROC
   END
    
   SET @cLabelGenCode = '[dbo].[' + @cLabelGenCode + ']'
   IF NOT EXISTS(SELECT 1 FROM sys.objects 
                 WHERE object_id = OBJECT_ID(@cLabelGenCode) 
                 AND type in (N'P', N'PC'))
   BEGIN
      SET @nErrNo = 78000
      SET @cErrMsg = 'Stored Procedure' + @cLabelGenCode + ' Not Exists in Database'
      GOTO EXIT_PROC       
   END
                    
   SET @cSQL = N'EXEC ' +  @cLabelGenCode + ' @cPickSlipNo, @nCartonNo, @cNewLabelNo OUTPUT'
   
   EXEC sp_ExecuteSQL @cSQL, N' @cPickSlipNo NVARCHAR(10), @nCartonNo INT, @cNewLabelNo NVARCHAR(20) OUTPUT', 
                      @cPickSlipNo, @nCartonNo, @cNewLabelNo OUTPUT 
   
   SET @nErrNo = @@ERROR                    
   IF @nErrNo <> 0 
   BEGIN
      SET @cErrMsg = 'Generate Label Number Failed'
      GOTO EXIT_PROC 
   END
   
   
EXIT_PROC:
RETURN
 
END

GO