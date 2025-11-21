SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTVerifyReplenishment           */
 /* Creation Date: 26-Feb-2013                                           */
 /* Copyright: IDS                                                       */
 /* Written by: Shong                                                    */
 /*                                                                      */
 /* Purposes: The message returns the regions where the operator is      */
 /*           allowed to perform the selection function.                 */
 /*                                                                      */
 /* Updates:                                                             */
 /* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTVerifyReplenishment] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@c_LOC          NVARCHAR(20)
   ,@c_SKU          NVARCHAR(20)
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT 

)
AS
BEGIN
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.
                                            -- 98: Critical error. If this error is received, 
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off. 
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message, 
                                            --     but does not force the operator to sign off.
         , @c_Message            NVARCHAR(400)
          ,@c_RegionNo           NVARCHAR(5)  -- OperatorΓÇÿs response to picking region prompt.         
         , @c_RegionName         NVARCHAR(100) 
         

   SET @c_RtnMessage = ''
   
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 
   BEGIN
      SET @c_RtnMessage = "1,0," 
   END
   


END

GO