SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_CCSkuRLFilter01                                     */
/* Creation Date: 14-MAR-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-4103 - [CR] KR UA ReleaseCCTask_GroupByAisle(Exceed)    */
/*        :                                                             */
/* Called By:  isp_CCSkuReleaseRules_Wrapper                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_CCSkuRLFilter01]
           @c_CountType NVARCHAR(10)
         , @c_Storerkey NVARCHAR(15)
         , @c_Sku       NVARCHAR(20) 
         , @c_Loc       NVARCHAR(20)
         , @b_Success   INT            OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1

   IF EXISTS(  SELECT 1
               FROM LOC WITH (NOLOCK)
               WHERE Loc = @c_Loc      
               AND EXISTS (SELECT 1
                           FROM CODELKUP CL WITH (NOLOCK)
                           WHERE CL.ListName = 'UACCPF'
                           AND   CL.Storerkey = @c_Storerkey      
                           AND   CL.Short = LOC.LocationType
                           )
            )
   BEGIN
      IF EXISTS ( SELECT 1 
                  FROM SKUxLOC SxL WITH (NOLOCK)
                  WHERE SxL.Storerkey = @c_Storerkey  
                  AND   SxL.Loc = @c_Loc
                  AND   SxL.QtyAllocated + SxL.QtyPicked > 0
                )
      BEGIN
         SET @n_Continue = 3
      END
   END

QUIT_SP:
   SET @b_Success = 1

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
   END
END -- procedure

GO