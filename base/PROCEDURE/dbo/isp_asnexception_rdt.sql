SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ASNException_RDT                                    */
/* Creation Date: 2021-05-10                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:  WMS-16957 - [CN]Nike_Phoeix_B2C_Exceed_Exception_Tracking  */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-05-10  Wan      1.0   Created                                   */
/************************************************************************/
CREATE PROC [dbo].[isp_ASNException_RDT]
   @c_DocumentNo        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT = @@TRANCOUNT

         , @c_ToLoc           NVARCHAR(30) = ''  
         , @dt_01_date        DATETIME             
         , @dt_02_date        DATETIME
         , @dt_03_date        DATETIME
         , @dt_04_date        DATETIME
         , @dt_05_date        DATETIME
         , @dt_06_date        DATETIME

   SET @c_DocumentNo = ISNULL(@c_DocumentNo,'')
   
   WHILE @@TRANCOUNT > 0 
   BEGIN 
      COMMIT TRAN
   END
   
   IF @c_DocumentNo = '' 
   BEGIN
      GOTO QUIT_SP
   END
   
   SELECT @dt_01_date = MAX(CASE WHEN dst.Key2= '01' THEN dst.EditDate ELSE NULL END)
         ,@dt_02_date = MAX(CASE WHEN dst.Key2= '02' THEN dst.EditDate ELSE NULL END)
         ,@dt_03_date = MAX(CASE WHEN dst.Key2= '03' THEN dst.EditDate ELSE NULL END)  
         ,@dt_04_date = MAX(CASE WHEN dst.Key2= '04' THEN dst.EditDate ELSE NULL END)  
         ,@dt_05_date = MAX(CASE WHEN dst.Key2= '05' THEN dst.EditDate ELSE NULL END)  
         ,@dt_06_date = MAX(CASE WHEN dst.Key2= '06' THEN dst.EditDate ELSE NULL END)  
   FROM dbo.DocStatusTrack AS dst WITH (NOLOCK) 
   WHERE dst.DocumentNo = @c_DocumentNo
   AND dst.TableName = 'EXCEPTIONRDT'
   
   SELECT TOP 1 @c_ToLoc    = ISNULL(dst.UserDefine04,'')               
   FROM dbo.DocStatusTrack AS dst WITH (NOLOCK) 
   WHERE dst.DocumentNo = @c_DocumentNo
   AND dst.TableName = 'EXCEPTIONRDT'
   ORDER BY dst.AddDate DESC
   
QUIT_SP:

   SELECT 'ToLoc'   = @c_ToLoc
         ,'01_date' = @dt_01_date
         ,'02_date' = @dt_02_date
         ,'03_date' = @dt_03_date   
         ,'04_date' = @dt_04_date   
         ,'05_date' = @dt_05_date   
         ,'06_date' = @dt_06_date   

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN 
      BEGIN TRAN
   END

END -- procedure

GO