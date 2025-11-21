SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
CREATE PROC [dbo].[Temp_Adidas_SwapCTLabel]                                                                                                                           
   @cStorerkey             NVARCHAR(10),                                                                                                                        
   @cFromRowRef            INT,                                                                                                                         
   @cToRowRef              INT,                                                                                                                        
   @cErrorMsg              NVARCHAR(255)       OUTPUT                                                                                                           
AS            
SET NOCOUNT ON                                                                                                                                               
SET ANSI_NULLS OFF                                                                                                                                           
SET QUOTED_IDENTIFIER OFF                                                                                                                                    
SET CONCAT_NULL_YIELDS_NULL OFF                                                          
  
DECLARE @cFromTrackingNo NVARCHAR(40), @cToTrackingNo NVARCHAR(40)  
,@cFromLabelNo NVARCHAR(40), @cToLabelNo NVARCHAR(40)  
  
SET @cFromTrackingNo = ''  
SET @cToTrackingNo = ''  
SET @cFromLabelNo = ''  
SET @cToLabelNo = ''  
  
SELECT @cFromTrackingNo = TrackingNo, @cFromLabelNo = LabelNo FROM CARTONTRACK WITH (NOLOCK) WHERE  
KEYNAME = @cStorerkey AND ROWREF = @cFromRowRef  
  
  
IF ISNULL(@cFromTrackingNo,'') = '' OR ISNULL(@cFromLabelNo,'') = ''  
BEGIN  
   SET @cErrorMsg = 'NO FROM ROWREF RECORD'  
   GOTO END_SP  
END  
  
  
SELECT @cToTrackingNo = TrackingNo, @cToLabelNo = LabelNo FROM CARTONTRACK WITH (NOLOCK) WHERE  
KEYNAME = @cStorerkey AND ROWREF = @cToRowRef  
  
  
IF ISNULL(@cToTrackingNo,'') = '' OR ISNULL(@cToLabelNo,'') = ''  
BEGIN  
   SET @cErrorMsg = 'NO TO ROWREF RECORD'  
   GOTO END_SP  
END  
  
BEGIN TRAN  
  
UPDATE CARTONTRACK WITH (ROWLOCK) SET TRACKINGNO = 'X'+TRACKINGNO WHERE ROWREF = @cFromRowRef  
IF @@ERROR <> 0  
BEGIN  
   SET @cErrorMsg = 'FAILED TO PREPARE FROM ROWREF'  
   GOTO ROLLBACK_SP  
END  
UPDATE CARTONTRACK WITH (ROWLOCK) SET TRACKINGNO = 'X'+TRACKINGNO WHERE ROWREF = @cToRowRef  
IF @@ERROR <> 0  
BEGIN  
   SET @cErrorMsg = 'FAILED TO PREPARE TO ROWREF'  
   GOTO ROLLBACK_SP  
END  
  
UPDATE CARTONTRACK WITH (ROWLOCK) SET TRACKINGNO = @cToTrackingNo, LABELNO = @cToLabelNo WHERE ROWREF = @cFromRowRef  
IF @@ERROR <> 0  
BEGIN  
   SET @cErrorMsg = 'FAILED TO UPDATE FROM ROWREF'  
   GOTO ROLLBACK_SP  
END  
UPDATE CARTONTRACK WITH (ROWLOCK) SET TRACKINGNO = @cFromTrackingNo, LABELNO = @cFromLabelNo WHERE ROWREF = @cToRowRef  
IF @@ERROR <> 0  
BEGIN  
   SET @cErrorMsg = 'FAILED TO UPDATE TO ROWREF'  
   GOTO ROLLBACK_SP  
END  
  
COMMIT TRAN  
GOTO END_SP
  
ROLLBACK_SP:  
BEGIN  
   ROLLBACK TRAN  
END  
  
  
  
END_SP:

GO