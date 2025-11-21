SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_EXG_MYWMS_NIKE_PICKING_RPT                      */
/* Creation Date: 10-Mar-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: GuanHao Chan                                              */
/*                                                                       */
/* Purpose: Excel Generator NIKE PICKING Report                          */
/*                                                                       */
/* Called By:                                                            */
/*                                                                       */
/* PVCS Version: -                                                       */
/*                                                                       */
/* Updates:                                                              */
/* Date          Author   Ver  Purposes                                  */
/* 10-Mar-2021   GHChan   1.0  Initial Development                       */
/*************************************************************************/


CREATE PROCEDURE [dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]
(
    @n_FileKey    INT            = 0,
    @n_EXG_Hdr_ID INT            = 0,
    @c_FileName   NVARCHAR(200)  = '',
    @c_SheetName  NVARCHAR(100)  = '',
    @c_Delimiter  NVARCHAR(2)    = '',
    @c_ParamVal1  NVARCHAR(200)  = '',
    @c_ParamVal2  NVARCHAR(200)  = '',
    @c_ParamVal3  NVARCHAR(200)  = '',
    @c_ParamVal4  NVARCHAR(200)  = '',
    @c_ParamVal5  NVARCHAR(200)  = '',
    @c_ParamVal6  NVARCHAR(200)  = '',
    @c_ParamVal7  NVARCHAR(200)  = '',
    @c_ParamVal8  NVARCHAR(200)  = '',
    @c_ParamVal9  NVARCHAR(200)  = '',
    @c_ParamVal10 NVARCHAR(200)  = '',
    @b_Debug      INT            = 1,
    @b_Success    INT            = 1   OUTPUT,
    @n_Err        INT            = 0   OUTPUT,
    @c_ErrMsg     NVARCHAR(250)  = ''  OUTPUT
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

    DECLARE @n_Continue       INT            = 1,
            @n_StartTcnt      INT            = @@TRANCOUNT,
            @c_DeliveryDate   NVARCHAR(30)   = N'',
            @c_CCompany       NVARCHAR(100)  = N'',
            @c_ConsigneeKey   NVARCHAR(15)   = N'',
            @c_TotalCarton    NVARCHAR(100)  = N'';
    /*********************************************/
    /* Variables Declaration (End)               */
    /*********************************************/

    IF @b_Debug = 1
    BEGIN
        PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: Start...';
        PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: ' + ',@n_FileKey=' + ISNULL(RTRIM(@n_FileKey), '')
              + ',@n_EXG_Hdr_ID=' + ISNULL(RTRIM(@n_EXG_Hdr_ID), '') + ',@c_FileName=' + ISNULL(RTRIM(@c_FileName), '')
              + ',@c_SheetName=' + ISNULL(RTRIM(@c_SheetName), '') + ',@c_Delimiter=' + ISNULL(RTRIM(@c_Delimiter), '')
              + ',@c_ParamVal1=' + ISNULL(RTRIM(@c_ParamVal1), '') + ',@c_ParamVal2=' + ISNULL(RTRIM(@c_ParamVal2), '')
              + ',@c_ParamVal3=' + ISNULL(RTRIM(@c_ParamVal3), '') + ',@c_ParamVal4=' + ISNULL(RTRIM(@c_ParamVal4), '')
              + ',@c_ParamVal5=' + ISNULL(RTRIM(@c_ParamVal5), '') + ',@c_ParamVal6=' + ISNULL(RTRIM(@c_ParamVal6), '')
              + ',@c_ParamVal7=' + ISNULL(RTRIM(@c_ParamVal7), '') + ',@c_ParamVal8=' + ISNULL(RTRIM(@c_ParamVal8), '')
              + ',@c_ParamVal9=' + ISNULL(RTRIM(@c_ParamVal9), '') + ',@c_ParamVal10='
              + ISNULL(RTRIM(@c_ParamVal10), '');
    END;

    BEGIN TRAN;
    BEGIN TRY

        SELECT @c_DeliveryDate = CONVERT(VARCHAR, o.DeliveryDate, 106),
               @c_CCompany = RTRIM(o.C_Company),
               @c_ConsigneeKey = RTRIM(o.ConsigneeKey),
               @c_TotalCarton = RTRIM(COUNT(DISTINCT o.LoadKey + pd.DropID))
        FROM dbo.TRANSMITLOG3 AS t WITH (NOLOCK)
            JOIN dbo.ORDERS AS o WITH (NOLOCK)
                ON t.key1 = o.OrderKey
            JOIN dbo.STORER AS c WITH (NOLOCK)
                ON o.ConsigneeKey = c.StorerKey
            JOIN dbo.LoadPlan AS l WITH (NOLOCK)
                ON l.LoadKey = o.LoadKey
            JOIN dbo.PackHeader AS h WITH (NOLOCK)
                ON h.OrderKey = o.OrderKey
            JOIN dbo.PackDetail AS pd WITH (NOLOCK)
                ON pd.PickSlipNo = h.PickSlipNo
        WHERE o.StorerKey = @c_ParamVal1
              AND t.transmitflag = '1'
              AND c.Email1 <> ''
              AND o.Status IN ( '5', '9' ) --KH04   
              AND l.Status IN ( '5', '9' ) --KH07   
              AND o.ConsigneeKey = @c_ParamVal4
              AND o.DeliveryDate = @c_ParamVal5
        GROUP BY c.Company,
                 o.StorerKey,
                 o.C_Company,
                 o.ConsigneeKey,
                 o.DeliveryDate;

        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT('"', [Delivery Date], '"', @c_Delimiter, '"', @c_DeliveryDate, '"') AS LineText1
        FROM
        (SELECT 'Delivery Date' AS [Delivery Date]) AS TEMP1;

        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT('"', [Customer Name], '"', @c_Delimiter, '"', @c_CCompany, '"') AS LineText1
        FROM
        (SELECT 'Customer Name' AS [Customer Name]) AS TEMP1;

        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT('"', [Ship To], '"', @c_Delimiter, '"', @c_ConsigneeKey, '"') AS LineText1
        FROM
        (SELECT 'Ship To' AS [Ship To]) AS TEMP1;

        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT('"', [Total Carton(s)], '"', @c_Delimiter, '"', @c_TotalCarton, '"') AS LineText1
        FROM
        (SELECT 'Total Carton(s)' AS [Total Carton(s)]) AS TEMP1;

        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT(
                         '"',
                         [DN Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         [Nike DD Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         [PO Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         Division,
                         '"',
                         @c_Delimiter,
                         '"',
                         Code,
                         '"',
                         @c_Delimiter,
                         '"',
                         Size,
                         '"',
                         @c_Delimiter,
                         '"',
                         [Material Descr],
                         '"',
                         @c_Delimiter,
                         '"',
                         QTY,
                         '"',
                         @c_Delimiter,
                         '"',
                         [Special Notes],
                         '"'
                     ) AS LineText1
        FROM
        (
            SELECT 'DN Number' AS [DN Number],
                   'Nike DD Number' AS [Nike DD Number],
                   'PO Number' AS [PO Number],
                   'Division' AS Division,
                   'Code' AS Code,
                   'Size' AS Size,
                   'Material Descr' AS [Material Descr],
                   'QTY' AS QTY,
                   'Special Notes' AS [Special Notes]
        ) AS TEMP1;


        INSERT INTO [dbo].[EXG_FileDet]
        (
            file_key,
            EXG_Hdr_ID,
            [FileName],
            SheetName,
            [Status],
            LineText1
        )
        SELECT @n_FileKey,
               @n_EXG_Hdr_ID,
               @c_FileName,
               @c_SheetName,
               'W',
               CONCAT(
                         '"',
                         [DN Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         [Nike DD Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         [PO Number],
                         '"',
                         @c_Delimiter,
                         '"',
                         Division,
                         '"',
                         @c_Delimiter,
                         '"',
                         Code,
                         '"',
                         @c_Delimiter,
                         '"',
                         Size,
                         '"',
                         @c_Delimiter,
                         '"',
                         [Material Descr],
                         '"',
                         @c_Delimiter,
                         '"',
                         QTY,
                         '"',
                         @c_Delimiter,
                         '"',
                         [Special Notes],
                         '"'
                     ) AS LineText1
        FROM
        (
            SELECT ISNULL(o.LoadKey, '') AS [DN Number],
                   ISNULL(o.ExternOrderKey, '') AS [Nike DD Number],
                   ISNULL(o.ExternPOKey, '') AS [PO Number],
                   ISNULL(   CASE
                                 WHEN s.BUSR7 = 10 THEN
                                     'AP'
                                 WHEN s.BUSR7 = 20 THEN
                                     'FW'
                                 WHEN s.BUSR7 = 30 THEN
                                     'EQ'
                                 ELSE
                                     NULL
                             END,
                             ''
                         ) AS Division,
                   ISNULL(SUBSTRING(s.Sku, 1, 6) + '-' + SUBSTRING(s.Sku, 7, 3), '') AS Code,
                   ISNULL(SUBSTRING(pd.SKU, 10, LEN(pd.SKU) - 9), '') AS Size,
                   ISNULL(s.DESCR, '') AS [Material Descr],
                   ISNULL(CAST(SUM(pd.Qty) AS NVARCHAR(10)), '') AS QTY,
                   '-' AS [Special Notes]
            FROM dbo.TRANSMITLOG3 AS t WITH (NOLOCK)
                JOIN dbo.ORDERS AS o WITH (NOLOCK)
                    ON t.key1 = o.OrderKey
                JOIN dbo.LoadPlan AS l WITH (NOLOCK)
                    ON l.LoadKey = o.LoadKey
                JOIN dbo.PackHeader AS p WITH (NOLOCK)
                    ON p.OrderKey = o.OrderKey
                JOIN dbo.PackDetail AS pd WITH (NOLOCK)
                    ON pd.PickSlipNo = p.PickSlipNo
                JOIN dbo.SKU AS s WITH (NOLOCK)
                    ON pd.StorerKey = s.StorerKey
                       AND pd.SKU = s.Sku
                LEFT OUTER JOIN dbo.CODELKUP AS c WITH (NOLOCK)
                    ON ISNULL(SUBSTRING(pd.SKU, 10, LEN(pd.SKU) - 9), '') = c.Code
                       AND c.LISTNAME = 'SIZESEQ'
                       AND c.Storerkey = ''
                       AND c.code2 = ''
            WHERE o.StorerKey = @c_ParamVal1
                  AND o.ConsigneeKey = @c_ConsigneeKey
                  AND o.DeliveryDate = @c_DeliveryDate
                  AND pd.Qty <> 0
                  AND t.transmitflag = '1'
                  AND o.Status IN (   CASE
                                          WHEN @c_ParamVal1 <> 'NIKESG' THEN
                                              '5'
                                      END, '9'
                                  )
                  AND l.Status IN (   CASE
                                          WHEN @c_ParamVal1 <> 'NIKESG' THEN
                                              '5'
                                      END, '9'
                                  )
            GROUP BY o.LoadKey,
                     o.ExternOrderKey,
                     o.ExternPOKey,
                     o.ConsigneeKey,
                     o.Facility,
                     s.BUSR7,
                     SUBSTRING(s.Sku, 1, 6) + '-' + SUBSTRING(s.Sku, 7, 3),
                     s.DESCR,
                     ISNULL(SUBSTRING(pd.SKU, 10, LEN(pd.SKU) - 9), ''),
                     c.Short
            ORDER BY c.Short OFFSET 0 ROWS
        ) AS TEMP2;

        --UPDATE t WITH (ROWLOCK)
        --SET transmitflag = '9'
        --FROM dbo.TRANSMITLOG3 AS t
        --    JOIN dbo.ORDERS AS o WITH (NOLOCK)
        --        ON t.key1 = o.OrderKey
        --    JOIN dbo.LoadPlan AS l WITH (NOLOCK)
        --        ON l.LoadKey = o.LoadKey --KH07
        --    JOIN dbo.PackHeader AS p WITH (NOLOCK)
        --        ON p.OrderKey = o.OrderKey --KH05
        --    JOIN dbo.PackDetail AS pd WITH (NOLOCK)
        --        ON pd.PickSlipNo = p.PickSlipNo
        --    JOIN dbo.STORER AS c WITH (NOLOCK)
        --        ON o.ConsigneeKey = c.StorerKey
        --WHERE t.key3 = @c_ParamVal1
        --      AND t.tablename = @c_ParamVal3
        --      AND t.transmitflag = '1'
        --      --AND   c.Email1      <> ''
        --      AND o.Status IN (   CASE
        --                              WHEN @c_ParamVal1 <> 'NIKESG' THEN
        --                                  '5'
        --                          END, '9'
        --                      ) --KH05
        --      AND l.Status IN (   CASE
        --                              WHEN @c_ParamVal1 <> 'NIKESG' THEN
        --                                  '5'
        --                          END, '9'
        --                      ) --KH07
        --      AND o.ConsigneeKey = @c_ConsigneeKey
        --      AND o.DeliveryDate = @c_DeliveryDate;

    END TRY
    BEGIN CATCH
        SET @n_Err = ERROR_NUMBER();
        SET @c_ErrMsg = ERROR_MESSAGE() + ' (isp_EXG_MYWMS_NIKE_PICKING_RPT)';
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
            PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
            PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
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
            PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: @c_ErrMsg=' + RTRIM(@c_ErrMsg);
            PRINT '[dbo].[isp_EXG_MYWMS_NIKE_PICKING_RPT]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR));
        END;
        RETURN;
    END;
/***********************************************/
/* Std - Error Handling (End)                  */
/***********************************************/
END; -- End Procedure  

GO