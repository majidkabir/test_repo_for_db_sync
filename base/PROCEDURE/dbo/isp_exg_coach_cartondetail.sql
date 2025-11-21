SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_EXG_Coach_CartonDetail                           */
/* Creation Date: 24-Mar-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: GuanHao Chan                                              */
/*                                                                       */
/* Purpose: Excel Generator COACH Carton Detail Report Sheet             */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date          Author   Ver  Purposes                                  */
/* 24-Mar-2022   GHChan   1.0  Initial Development                       */
/*************************************************************************/


CREATE PROCEDURE [dbo].[isp_EXG_Coach_CartonDetail] (
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

   IF @b_Debug = 1
   BEGIN
      PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: Start...';
      PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: ' + ',@n_FileKey=' + ISNULL(RTRIM(@n_FileKey), '') + ',@n_EXG_Hdr_ID='
            + ISNULL(RTRIM(@n_EXG_Hdr_ID), '') + ',@c_FileName=' + ISNULL(RTRIM(@c_FileName), '') + ',@c_SheetName='
            + ISNULL(RTRIM(@c_SheetName), '') + ',@c_Delimiter=' + ISNULL(RTRIM(@c_Delimiter), '') + ',@c_ParamVal1='
            + ISNULL(RTRIM(@c_ParamVal1), '') + ',@c_ParamVal2=' + ISNULL(RTRIM(@c_ParamVal2), '') + ',@c_ParamVal3='
            + ISNULL(RTRIM(@c_ParamVal3), '') + ',@c_ParamVal4=' + ISNULL(RTRIM(@c_ParamVal4), '') + ',@c_ParamVal5='
            + ISNULL(RTRIM(@c_ParamVal5), '') + ',@c_ParamVal6=' + ISNULL(RTRIM(@c_ParamVal6), '') + ',@c_ParamVal7='
            + ISNULL(RTRIM(@c_ParamVal7), '') + ',@c_ParamVal8=' + ISNULL(RTRIM(@c_ParamVal8), '') + ',@c_ParamVal9='
            + ISNULL(RTRIM(@c_ParamVal9), '') + ',@c_ParamVal10=' + ISNULL(RTRIM(@c_ParamVal10), '');
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
                '"', TEMP1.[GI Date], '"', @c_Delimiter, '"', TEMP1.Brand, '"', @c_Delimiter, '"', TEMP1.[Shipping Point], '"'
              , @c_Delimiter, '"', TEMP1.[WMS Order#], '"', @c_Delimiter, '"', TEMP1.SO#, '"', @c_Delimiter, '"', TEMP1.OBD#, '"'
              , @c_Delimiter, '"', TEMP1.[Customer PO#], '"', @c_Delimiter, '"', TEMP1.[Location], '"', @c_Delimiter, '"'
              , TEMP1.[Sold to#], '"', @c_Delimiter, '"', TEMP1.[Ship to#], '"', @c_Delimiter, '"', TEMP1.[Ship to Name], '"'
              , @c_Delimiter, '"', TEMP1.MOT, '"', @c_Delimiter, '"', TEMP1.Pallet#, '"', @c_Delimiter, '"', TEMP1.Carton#, '"'
              , @c_Delimiter, '"', TEMP1.[WMS SKU], '"', @c_Delimiter, '"', TEMP1.[S4 SKU], '"', @c_Delimiter, '"', TEMP1.UPC
              , '"', @c_Delimiter, '"', TEMP1.[Retail Price], '"', @c_Delimiter, '"', TEMP1.LabelLine, '"', @c_Delimiter, '"'
              , TEMP1.Qty, '"', @c_Delimiter, '"', TEMP1.Dept#, '"', @c_Delimiter, '"', TEMP1.[Department Description], '"'
              , @c_Delimiter
             ) AS LineText1
      FROM (
      SELECT 'GI Date'                AS 'GI Date'
           , 'Brand'                  AS 'Brand'
           , 'Shipping Point'         AS 'Shipping Point'
           , 'WMS Order#'             AS 'WMS Order#'
           , 'SO#'                    AS 'SO#'
           , 'OBD#'                   AS 'OBD#'
           , 'Customer PO#'           AS 'Customer PO#'
           , 'Location'               AS 'Location'
           , 'Sold to#'               AS 'Sold to#'
           , 'Ship to#'               AS 'Ship to#'
           , 'Ship to Name'           AS 'Ship to Name'
           , 'MOT'                    AS 'MOT'
           , 'Pallet#'                AS 'Pallet#'
           , 'Carton#'                AS 'Carton#'
           , 'WMS SKU'                AS 'WMS SKU'
           , 'S4 SKU'                 AS 'S4 SKU'
           , 'UPC'                    AS 'UPC'
           , 'Retail Price'           AS 'Retail Price'
           , 'LabelLine'              AS 'LabelLine'
           , 'Qty'                    AS 'Qty'
           , 'Dept#'                  AS 'Dept#'
           , 'Department Description' AS 'Department Description'
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
                '"', TEMP2.[GI Date], '"', @c_Delimiter, '"', TEMP2.Brand, '"', @c_Delimiter, '"', TEMP2.[Shipping Point], '"'
              , @c_Delimiter, '"', TEMP2.[WMS Order#], '"', @c_Delimiter, '"', TEMP2.SO#, '"', @c_Delimiter, '"', TEMP2.OBD#, '"'
              , @c_Delimiter, '"', TEMP2.[Customer PO#], '"', @c_Delimiter, '"', TEMP2.[Location], '"', @c_Delimiter, '"'
              , TEMP2.[Sold to#], '"', @c_Delimiter, '"', TEMP2.[Ship to#], '"', @c_Delimiter, '"', TEMP2.[Ship to Name], '"'
              , @c_Delimiter, '"', TEMP2.MOT, '"', @c_Delimiter, '"', TEMP2.Pallet#, '"', @c_Delimiter, '"', TEMP2.Carton#, '"'
              , @c_Delimiter, '"', TEMP2.[WMS SKU], '"', @c_Delimiter, '"', TEMP2.[S4 SKU], '"', @c_Delimiter, '"', TEMP2.UPC
              , '"', @c_Delimiter, '"', TEMP2.[Retail Price], '"', @c_Delimiter, '"', TEMP2.LabelLine, '"', @c_Delimiter, '"', TEMP2.Qty
              , '"', @c_Delimiter, '"', TEMP2.Dept#, '"', @c_Delimiter, '"', TEMP2.[Department Description], '"', @c_Delimiter
             ) AS LineText1
      FROM (
      SELECT CONVERT(VARCHAR(10), PD.EditDate, 111) AS 'GI Date'
           , O.StorerKey                            AS 'Brand'
           , 'CN10'                                 AS 'Shipping Point'
           , O.OrderKey                             AS 'WMS Order#'
           , O.ExternPOKey                          AS 'SO#'
           , O.ExternOrderKey                       AS 'OBD#'
           , O.xdockpokey                           AS 'Customer PO#'
           , O.UserDefine01                         AS 'Location'
           , O.BillToKey                            AS 'Sold to#'
           , O.ConsigneeKey                         AS 'Ship to#'
           , O.C_Address4                           AS 'Ship to Name'
           , N'华企陆运'                               AS 'MOT'
           , ''                                     AS 'Pallet#'
           , PD.LabelNo                             AS 'Carton#'
           , PD.SKU                                 AS 'WMS SKU'
           , sku.MANUFACTURERSKU                    AS 'S4 SKU'
           , sku.ALTSKU                             AS 'UPC'
           , sku.Price                              AS 'Retail Price'
           , PD.LabelLine                           AS 'LabelLine'
           , PD.Qty                                 AS 'Qty'
           , sku.SUSR3                              AS 'Dept#'
           , sku.BUSR3                              AS 'Department Description'
      FROM MBOL (NOLOCK)       m
      JOIN MBOLDETAIL (NOLOCK) md
      ON m.MbolKey          = md.MbolKey
      JOIN ORDERS (NOLOCK)     O
      ON  md.OrderKey        = O.OrderKey
      AND md.ExternOrderKey = O.ExternOrderKey
      JOIN STORER (NOLOCK)     s
      ON s.StorerKey        = O.StorerKey
      JOIN PackHeader (NOLOCK) PH
      ON  O.StorerKey        = PH.StorerKey
      AND O.OrderKey        = PH.OrderKey
      JOIN PackDetail (NOLOCK) PD
      ON  PH.StorerKey       = PD.StorerKey
      AND PH.PickSlipNo     = PD.PickSlipNo
      JOIN SKU (NOLOCK)        sku
      ON  sku.StorerKey      = PD.StorerKey
      AND sku.Sku           = PD.SKU
      WHERE O.StorerKey  = @c_ParamVal1
      AND   m.MbolKey      = @c_ParamVal2
      AND   O.ConsigneeKey = @c_ParamVal3
      AND   m.Status       = '9'
      ) AS TEMP2;

      UPDATE dbo.TRANSMITLOG3 WITH (ROWLOCK)
      SET transmitflag = '9'
      WHERE transmitlogkey = @c_ParamVal4;

   END TRY
   BEGIN CATCH
      SET @n_Err = ERROR_NUMBER();
      SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_Coach_CartonDetail)';
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
         PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
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
         PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
         PRINT '[dbo].[isp_EXG_Coach_CartonDetail]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
      END;
      RETURN;
   END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; -- End Procedure  

GO