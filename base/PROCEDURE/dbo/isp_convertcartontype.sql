SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: isp_ConvertCartonType                                       */
/* Creation Date: 13-Apr-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19431 - Normal packing Convert carton type              */
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
/* 13-APR-2022 NJOW     1.0   DEVOPS combine script                     */
/************************************************************************/
CREATE PROC [dbo].[isp_ConvertCartonType]
         @c_Facility      NVARCHAR(5)
      ,  @c_Storerkey     NVARCHAR(15)
      ,  @c_CartonType    NVARCHAR(30)
      ,  @c_NewCartonType NVARCHAR(10) OUTPUT
      ,  @c_CartonGroup   NVARCHAR(10)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(250)
         , @c_CtnTypeConvert  NVARCHAR(30)
         , @c_Option1         NVARCHAR(50)
         , @c_Option2         NVARCHAR(50)
         , @c_Option3         NVARCHAR(50)
         , @c_Option4         NVARCHAR(50)
         , @c_Option5         NVARCHAR(4000)
         , @c_TempCartonType  NVARCHAR(10)

   SELECT @b_Success = 1, @n_err = 0, @c_errmsg = ''
   SELECT @c_NewCartonType = '', @c_TempCartonType = '', @c_CtnTypeConvert = ''

   EXEC nspGetRight
          @c_Facility
       ,  @c_StorerKey
       ,  ''
       ,  'CtnTypeConvert'
       ,  @b_Success         OUTPUT
       ,  @c_CtnTypeConvert  OUTPUT
       ,  @n_err             OUTPUT
       ,  @c_errmsg          OUTPUT

   IF @b_Success <> 1  OR ISNULL(@c_CtnTypeConvert,'') <> '1'
   BEGIN
      GOTO QUIT_SP
   END

   IF ISNULL(@c_CartonGroup,'') = ''
   BEGIN
      SELECT @c_CartonGroup = RTRIM(CartonGroup)
      FROM STORER WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
   END

   IF LEN(@c_CartonType) > 10
   OR NOT EXISTS(SELECT 1
                 FROM CARTONIZATION (NOLOCK)
                 WHERE CartonizationGroup = @c_CartonGroup
                 AND CartonType = @c_CartonType)
   BEGIN
      SELECT TOP 1 @c_TempCartonType = CartonType
      FROM CARTONIZATION (NOLOCK)
      WHERE CartonizationGroup = @c_CartonGroup
      AND Barcode = @c_CartonType

      IF ISNULL(@c_TempCartonType,'') <> ''
      BEGIN
         SET @c_NewCartonType = @c_TempCartonType
      END
   END

   QUIT_SP:

 	 IF LEN(@c_CartonType) > 10 AND ISNULL(@c_NewCartonType,'') = ''
  	  SET @c_NewCartonType = LEFT(@c_CartonType,10)
END -- procedure

GO