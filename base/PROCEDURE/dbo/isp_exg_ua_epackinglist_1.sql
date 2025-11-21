SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_EXG_UA_EPackingList_1                             */
/* Creation Date: 01-Jul-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: GuanHao Chan                                              */
/*                                                                       */
/* Purpose: Excel Generator UA EPackingList Report Sheet                 */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date          Author   Ver  Purposes                                  */
/* 24-Mar-2022   GHChan   1.0  Initial Development                       */
/*************************************************************************/


CREATE PROCEDURE [dbo].[isp_EXG_UA_EPackingList_1] (
   @n_FileKey    INT           = 0
 , @n_EXG_Hdr_ID INT           = 0
 , @c_FileName   NVARCHAR(200) = ''
 , @c_SheetName  NVARCHAR(100) = ''
 , @c_Delimiter  NVARCHAR(2)   = ''
 , @c_ParamVal1  NVARCHAR(200) = ''
 , @c_ParamVal2  NVARCHAR(200) = ''
 , @c_ParamVal3  NVARCHAR(200) = ''
 , @c_ParamVal4  NVARCHAR(200) = ''
 , @c_ParamVal5  NVARCHAR(200) = ''
 , @c_ParamVal6  NVARCHAR(200) = ''
 , @c_ParamVal7  NVARCHAR(200) = ''
 , @c_ParamVal8  NVARCHAR(200) = ''
 , @c_ParamVal9  NVARCHAR(200) = ''
 , @c_ParamVal10 NVARCHAR(200) = ''
 , @b_Debug      INT           = 1
 , @b_Success    INT           = 1 OUTPUT
 , @n_Err        INT           = 0 OUTPUT
 , @c_ErrMsg     NVARCHAR(250) = '' OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON;
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/

   DECLARE @n_Continue  INT = 1
         , @n_StartTcnt INT = @@TRANCOUNT;
   /*********************************************/
   /* Variables Declaration (End)               */
   /*********************************************/

   DECLARE @temptable TABLE (
      Col01 NVARCHAR(50)
    , Col02 NVARCHAR(50)
    , Col03 NVARCHAR(10)
    , Col04 NVARCHAR(50)
    , Col05 NVARCHAR(10)
    , Col06 NVARCHAR(20)
    , Col07 NVARCHAR(20)
    , Col08 NVARCHAR(20)
    , Col09 NVARCHAR(100)
    , Col10 INT
    , Col11 NVARCHAR(20)
    , Col12 NVARCHAR(60)
    , Col13 NVARCHAR(20)
    , Col14 INT
    , Col15 INT
    , Col16 NVARCHAR(40)
   );
   IF @b_Debug = 1
   BEGIN
      PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: Start...';
      PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: ' + ',@n_FileKey=' + ISNULL(RTRIM(@n_FileKey), '') + ',@n_EXG_Hdr_ID='
            + ISNULL(RTRIM(@n_EXG_Hdr_ID), '') + ',@c_FileName=' + ISNULL(RTRIM(@c_FileName), '') + ',@c_SheetName='
            + ISNULL(RTRIM(@c_SheetName), '') + ',@c_Delimiter=' + ISNULL(RTRIM(@c_Delimiter), '') + ',@c_ParamVal1='
            + ISNULL(RTRIM(@c_ParamVal1), '') + ',@c_ParamVal2=' + ISNULL(RTRIM(@c_ParamVal2), '') + ',@c_ParamVal3='
            + ISNULL(RTRIM(@c_ParamVal3), '') + ',@c_ParamVal4=' + ISNULL(RTRIM(@c_ParamVal4), '') + ',@c_ParamVal5='
            + ISNULL(RTRIM(@c_ParamVal5), '') + ',@c_ParamVal6=' + ISNULL(RTRIM(@c_ParamVal6), '') + ',@c_ParamVal7='
            + ISNULL(RTRIM(@c_ParamVal7), '') + ',@c_ParamVal8=' + ISNULL(RTRIM(@c_ParamVal8), '') + ',@c_ParamVal9='
            + ISNULL(RTRIM(@c_ParamVal9), '') + ',@c_ParamVal10=' + ISNULL(RTRIM(@c_ParamVal10), '');
   END;

   INSERT INTO @temptable
   (
      Col01
    , Col02
    , Col03
    , Col04
    , Col05
    , Col06
    , Col07
    , Col08
    , Col09
    , Col10
    , Col11
    , Col12
    , Col13
    , Col14
    , Col15
    , Col16
   )
   EXEC KRLOCAL.dbo.nsp_UnderArmour_E_Packing_List_1 @ORDERKEY = @c_ParamVal2;

   IF NOT EXISTS (SELECT 1 FROM @temptable)
   BEGIN
      SET @n_Err = 10001;
      SET @c_ErrMsg = ' No records found! (isp_EXG_UA_EPackingList_1)';
      SET @n_Continue = 3;

      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = '5'
      WHERE transmitlogkey = @c_ParamVal5;
      GOTO QUIT;
   END;

   BEGIN TRAN;
   BEGIN TRY

      INSERT INTO [dbo].[EXG_FileDet]
      (
         file_key
       , EXG_Hdr_ID
       , [FileName]
       , SheetName
       , [Status]
       , LineText1
      )
      SELECT @n_FileKey
           , @n_EXG_Hdr_ID
           , @c_FileName
           , @c_SheetName
           , 'W'
           , CONCAT(
                '"', TEMP1.[Storecode], '"', @c_Delimiter, '"', TEMP1.[Storename], '"', @c_Delimiter, '"', TEMP1.[Userdefine09]
              , '"', @c_Delimiter, '"', TEMP1.[OBD#], '"', @c_Delimiter, '"', TEMP1.[Orderkey], '"', @c_Delimiter, '"'
              , TEMP1.[T-Mode], '"', @c_Delimiter, '"', TEMP1.[DropID], '"', @c_Delimiter, '"', TEMP1.[LabelNo], '"'
              , @c_Delimiter, '"', TEMP1.[C_Contact1], '"', @c_Delimiter, '"', TEMP1.[CartonNo], '"', @c_Delimiter, '"'
              , TEMP1.[SKU], '"', @c_Delimiter, '"', TEMP1.[DESCR], '"', @c_Delimiter, '"', TEMP1.[ALTSKU], '"', @c_Delimiter
              , '"', TEMP1.[QTY], '"', @c_Delimiter, '"', TEMP1.[총박스수량], '"', @c_Delimiter, '"', TEMP1.[TrackingNo], '"'
              , @c_Delimiter
             ) AS LineText1
      FROM (
      SELECT 'Storecode'    AS [Storecode]
           , 'Storename'    AS [Storename]
           , 'Userdefine09' AS [Userdefine09]
           , 'OBD#'         AS [OBD#]
           , 'Orderkey'     AS [Orderkey]
           , 'T-Mode'       AS [T-Mode]
           , 'DropID'       AS [DropID]
           , 'LabelNo'      AS [LabelNo]
           , 'C_Contact1'   AS [C_Contact1]
           , 'CartonNo'     AS [CartonNo]
           , 'SKU'          AS [SKU]
           , 'DESCR'        AS [DESCR]
           , 'ALTSKU'       AS [ALTSKU]
           , 'QTY'          AS [QTY]
           , N'총박스수량'       AS [총박스수량]
           , 'TrackingNo'   AS [TrackingNo]
      ) AS TEMP1;



      INSERT INTO [dbo].[EXG_FileDet]
      (
         file_key
       , EXG_Hdr_ID
       , [FileName]
       , SheetName
       , [Status]
       , LineText1
      )
      SELECT @n_FileKey
           , @n_EXG_Hdr_ID
           , @c_FileName
           , @c_SheetName
           , 'W'
           , CONCAT(
                '"', TEMP2.[Storecode], '"', @c_Delimiter, '"', TEMP2.[Storename], '"', @c_Delimiter, '"', TEMP2.[Userdefine09]
              , '"', @c_Delimiter, '"', TEMP2.[OBD#], '"', @c_Delimiter, '"', TEMP2.[Orderkey], '"', @c_Delimiter, '"'
              , TEMP2.[T-Mode], '"', @c_Delimiter, '"', TEMP2.[DropID], '"', @c_Delimiter, '"', TEMP2.[LabelNo], '"'
              , @c_Delimiter, '"', TEMP2.[C_Contact1], '"', @c_Delimiter, '"', TEMP2.[CartonNo], '"', @c_Delimiter, '"'
              , TEMP2.[SKU], '"', @c_Delimiter, '"', TEMP2.[DESCR], '"', @c_Delimiter, '"', TEMP2.[ALTSKU], '"', @c_Delimiter
              , '"', TEMP2.[QTY], '"', @c_Delimiter, '"', TEMP2.[총박스수량], '"', @c_Delimiter, '"', TEMP2.[TrackingNo], '"'
              , @c_Delimiter
             ) AS LineText1
      FROM (
      SELECT Col01 AS [Storecode]
           , Col02 AS [Storename]
           , Col03 AS [Userdefine09]
           , Col04 AS [OBD#]
           , Col05 AS [Orderkey]
           , Col06 AS [T-Mode]
           , Col07 AS [DropID]
           , Col08 AS [LabelNo]
           , Col09 AS [C_Contact1]
           , Col10 AS [CartonNo]
           , Col11 AS [SKU]
           , Col12 AS [DESCR]
           , Col13 AS [ALTSKU]
           , Col14 AS [QTY]
           , Col15 AS [총박스수량]
           , Col16 AS [TrackingNo]
      FROM @temptable
      ) AS TEMP2;

      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = '2'
      WHERE transmitlogkey = @c_ParamVal5;

   END TRY
   BEGIN CATCH
      SET @n_Err = ERROR_NUMBER();
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_UA_EPackingList_1)';
      SET @n_Continue = 3;
   END CATCH;

   QUIT:
   WHILE @@TRANCOUNT > 0
   COMMIT TRAN;

   WHILE @@TRANCOUNT < @n_StartTcnt
   BEGIN TRAN;

   IF @n_Continue = 3 -- Error Occured - Process And Return        
   BEGIN
      SELECT @b_Success = 0;
      IF @@TRANCOUNT > @n_StartTcnt
      BEGIN
         ROLLBACK TRAN;
      END;
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTcnt
         BEGIN
            COMMIT TRAN;
         END;
      END;

      IF @b_Debug = 1
      BEGIN
         PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
      END;

      RETURN;
   END;
   ELSE
   BEGIN
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''
      BEGIN
         SELECT @b_Success = 0;
      END;
      ELSE
      BEGIN
         SELECT @b_Success = 1;
      END;

      WHILE @@TRANCOUNT > @n_StartTcnt
      BEGIN
         COMMIT TRAN;
      END;

      IF @b_Debug = 1
      BEGIN
         PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_UA_EPackingList_1]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
      END;
      RETURN;
   END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; -- End Procedure  

GO