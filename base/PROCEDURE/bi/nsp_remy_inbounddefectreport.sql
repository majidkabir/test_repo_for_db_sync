SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
-- https://jiralfl.atlassian.net/browse/BI-197
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 12-July-2021  GuanHaoChan 1.0   Created                                  */
/***************************************************************************/
CREATE PROCEDURE [BI].[nsp_REMY_InboundDefectReport]
    -- Add the parameters for the stored procedure here
    @c_Key1 NVARCHAR(20) = '' -- BL Number
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;
    -- Insert statements for procedure here

    DECLARE @n_RecordID INT,
            @c_TableName NVARCHAR(20),
            --, @n_LineSeq         INT
            @c_Data NVARCHAR(2000),
            @c_SKUDescr NVARCHAR(60),
            @c_BasePath_Win NVARCHAR(100),
            @c_BasePath_Linux NVARCHAR(100),
            @c_StorerKey NVARCHAR(15);

    DECLARE @tempJson TABLE
    (
        ContainerNumber NVARCHAR(100) NULL,
        ReceiptKey NVARCHAR(10) NULL,
        SKU NVARCHAR(20) NULL,
        LOT# NVARCHAR(50) NULL,
        DefectCode NVARCHAR(50) NULL,
        DefectQty NVARCHAR(10) NULL,
        Remarks NVARCHAR(2000) NULL,
        ImageName NVARCHAR(100) NULL
    );

    CREATE TABLE #RemyInboundDefectReport
    (
        Defect# NVARCHAR(50) NOT NULL,
        ReceiptKey NVARCHAR(10) NOT NULL,
        SKU NVARCHAR(20) NOT NULL,
        SKU_Descr NVARCHAR(60) NULL,
        LOT# NVARCHAR(20) NOT NULL,
        DefectCode NVARCHAR(50) NOT NULL,
        DefectQty NVARCHAR(10) NOT NULL,
        Remarks NVARCHAR(2000) NULL,
        ImgPath_Win NVARCHAR(255) NOT NULL,
        ImgPath_Linux NVARCHAR(255) NOT NULL
    );

    SET @c_TableName = N'IMPR_CONT_PO_SKU';

    -- DocInfo.Key1 <--> Container Number
    -- DocInfo.Key2 <--> ReceiptKey/ASN#
    -- DocInfo.Key3 <--> SKU

    DECLARE C_TBLARR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT D.RecordID,
           ISNULL(RTRIM(D.[Data]), ''),
           ISNULL(RTRIM(S.DESCR), ''),
           D.StorerKey
    --, LineSeq
    FROM dbo.V_DocInfo D WITH (NOLOCK)
        INNER JOIN dbo.V_SKU S WITH (NOLOCK)
            ON S.StorerKey = D.StorerKey
               AND S.Sku = D.Key3
        INNER JOIN dbo.V_RECEIPT R WITH (NOLOCK)
            ON R.ReceiptKey = D.Key2
               AND R.StorerKey = S.StorerKey
    WHERE D.TableName = @c_TableName
          AND R.CarrierReference = @c_Key1;

    OPEN C_TBLARR;
    FETCH NEXT FROM C_TBLARR
    INTO @n_RecordID,
         @c_Data,
         @c_SKUDescr,
         @c_StorerKey;

    WHILE (@@FETCH_STATUS <> -1)
    BEGIN
        --UAT
        --SET @c_BasePath_Win = CONCAT('\\\\VMHKEPODISGUT1\ImageMgr\PhotoRepo\WMS\CHN\', @c_StorerKey, '\IN_DMG\');
        --SET @c_BasePath_Linux = CONCAT('/mnt/PhotoRepo_UAT/WMS/CHN/', @c_StorerKey, '/IN_DMG/');

        --PROD
        SET @c_BasePath_Win = CONCAT('\\\\VMHKEPODISGPD1\ImageMgr\PhotoRepo\WMS\CHN\', @c_StorerKey, '\IN_DMG\')
        SET @c_BasePath_Linux = CONCAT('/mnt/PhotoRepo_PROD/WMS/CHN/', @c_StorerKey, '/IN_DMG/')

        IF @c_Data != ''
           AND ISJSON(@c_Data) > 0
        BEGIN
            DELETE FROM @tempJson;

            INSERT INTO @tempJson
            (
                ContainerNumber,
                ReceiptKey,
                SKU,
                LOT#,
                DefectCode,
                DefectQty,
                Remarks,
                ImageName
            )
            SELECT ContainerNumber,
                   ReceiptKey,
                   SKU,
                   LOT#,
                   DefectCode,
                   DefectQty,
                   Remarks,
                   CONCAT(ContainerNumber, '_', ReceiptKey, '_', SKU, '_', LOT#, '_', DefectCode, '_', [Value]) AS ImageName
            FROM
                OPENJSON(@c_Data)
                WITH
                (
                    ContainerNumber NVARCHAR(100) '$.col3', --col7  <--> ContainerNumber
                    ReceiptKey NVARCHAR(10) '$.col4',       --col7  <--> ReceiptKey
                    SKU NVARCHAR(20) '$.col5',              --col7  <--> SKU
                    LOT# NVARCHAR(50) '$.col6',             --col7  <--> LOT#
                    DefectCode NVARCHAR(50) '$.col7',       --col7  <--> DefectCode
                    DefectQty NVARCHAR(10) '$.col8',        --col8  <--> DefectQty
                    Remarks NVARCHAR(2000) '$.col15',       --col15 <--> Remarks
                    ListImageName NVARCHAR(MAX) '$.ListImageName' AS JSON
                ) AS Main
                CROSS APPLY OPENJSON(Main.ListImageName);

            INSERT INTO #RemyInboundDefectReport
            (
                Defect#,
                ReceiptKey,
                SKU,
                SKU_Descr,
                LOT#,
                DefectCode,
                DefectQty,
                Remarks,
                ImgPath_Win,
                ImgPath_Linux
            )
            SELECT CONCAT(x.ReceiptKey, x.LOT#, x.DefectCode) AS [Defect#],
                   x.ReceiptKey,
                   x.SKU,
                   @c_SKUDescr,
                   x.LOT#,
                   x.DefectCode,
                   CAST(SUM(x.QTY) AS NVARCHAR(10)),
                   j.Remarks,
                   CONCAT(
                             @c_BasePath_Win,
                             x.ContainerNumber,
                             '_',
                             x.ReceiptKey,
                             '\',
                             x.SKU,
                             '\',
                             x.LOT#,
                             '\',
                             x.DefectCode,
                             '\',
                             j.ImageName
                         ),
                   CONCAT(
                             @c_BasePath_Linux,
                             x.ContainerNumber,
                             '_',
                             x.ReceiptKey,
                             '/',
                             x.SKU,
                             '/',
                             x.LOT#,
                             '/',
                             x.DefectCode,
                             '/',
                             j.ImageName
                         )
            FROM
            (
                SELECT ContainerNumber,
                       ReceiptKey,
                       SKU,
                       LOT#,
                       DefectCode,
                       CAST(DefectQty AS INT) AS QTY
                FROM @tempJson
                GROUP BY ContainerNumber,
                         ReceiptKey,
                         SKU,
                         LOT#,
                         DefectCode,
                         DefectQty
            ) x
                INNER JOIN @tempJson j
                    ON j.ContainerNumber = x.ContainerNumber
                       AND j.DefectCode = x.DefectCode
                       AND j.LOT# = x.LOT#
                       AND j.ReceiptKey = x.ReceiptKey
                       AND j.SKU = x.SKU
            GROUP BY x.ContainerNumber,
                     x.ReceiptKey,
                     x.SKU,
                     x.LOT#,
                     x.DefectCode,
                     x.ReceiptKey,
                     j.Remarks,
                     j.ImageName;
        END;

        FETCH NEXT FROM C_TBLARR
        INTO @n_RecordID,
             @c_Data,
             @c_SKUDescr,
             @c_StorerKey;
    END;
    CLOSE C_TBLARR;
    DEALLOCATE C_TBLARR;

    SELECT CASE
               WHEN (ROW_NUMBER() OVER (PARTITION BY IDR.Defect# ORDER BY IDR.Defect#) % 8) = 0 THEN
        (ROW_NUMBER() OVER (PARTITION BY IDR.Defect# ORDER BY IDR.Defect#) / 8) + 0
               ELSE
        (ROW_NUMBER() OVER (PARTITION BY IDR.Defect# ORDER BY IDR.Defect#) / 8) + 1
           END AS picturenumber,
           @c_Key1 AS [BL Number],
           IDR.Defect#,
           IDR.SKU,
           IDR.SKU_Descr,
           IDR.LOT#,
           IDR.DefectCode,
           IDR.DefectQty,
           IDR.Remarks,
           IDR.ImgPath_Win,
           IDR.ImgPath_Linux
    FROM #RemyInboundDefectReport IDR WITH (NOLOCK);
    DROP TABLE #RemyInboundDefectReport;

END; --End Stored Procedure

GO