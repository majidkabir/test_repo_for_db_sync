SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPackDetail_Carton                                */
/* Creation Date: 2020-04-07                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-12722 - SG - PMI - Packing [CR]                         */
/*        : Change DW Select to Store Procedure                         */
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
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackDetail_Carton]
           @c_PickslipNo      NVARCHAR(10)
         , @n_CartonNo        INT 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt                INT            = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   IF @n_CartonNo > 0
   BEGIN
      SELECT DISTINCT 
            CARTONNO
         ,  LABELNO   
      FROM PACKDETAIL (NOLOCK) 
      WHERE PICKSLIPNO = @c_PickslipNo
      AND   CartonNo = @n_CartonNo
   END
   ELSE
   BEGIN
      SELECT DISTINCT 
            CARTONNO
         ,  LABELNO   
      FROM PACKDETAIL (NOLOCK) 
      WHERE PICKSLIPNO = @c_PickslipNo
   END

QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO