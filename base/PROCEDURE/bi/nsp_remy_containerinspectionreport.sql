SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
-- https://jiralfl.atlassian.net/browse/BI-197
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 19-July-2021  GuanHaoChan 1.0   Created                                  */
/***************************************************************************/
CREATE PROCEDURE [BI].[nsp_REMY_ContainerInspectionReport]
    -- Add the parameters for the stored procedure here
    --@c_StorerKey NVARCHAR(15) = '',
    @c_Key1 NVARCHAR(20) = ''
--@c_Key2 NVARCHAR(20) = ''
--@c_Key3 NVARCHAR(20) = ''
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_NULLS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;
    -- Insert statements for procedure here

    DECLARE @c_TableName NVARCHAR(20),
            @c_BasePath_Win NVARCHAR(100),
            @c_BasePath_Linux NVARCHAR(100),
            @c_StorerKey NVARCHAR(15);

    SET @c_TableName = N'IMPR_CONT_PO';

    --UAT
    --SET @c_BasePath_Win = N'\\\\VMHKEPODISGUT1\ImageMgr\PhotoRepo\WMS\CHN\';
    --SET @c_BasePath_Linux = N'/mnt/PhotoRepo_UAT/WMS/CHN/';

    --PROD
    SET @c_BasePath_Win = '\\\\VMHKEPODISGPD1\ImageMgr\PhotoRepo\WMS\CHN\'
    SET @c_BasePath_Linux = '/mnt/PhotoRepo_PROD/WMS/CHN/'


    -- DocInfo.Key1 <--> ContainerKey
    -- DocInfo.Key2 <--> ReceiptKey

    SELECT
        --CASE
        --           WHEN (ROW_NUMBER() OVER (PARTITION BY DI.Key1, R.ReceiptKey ORDER BY DI.Key1, R.ReceiptKey) % 8) = 0 THEN
        --    (ROW_NUMBER() OVER (PARTITION BY DI.Key1, R.ReceiptKey ORDER BY DI.Key1, R.ReceiptKey) / 8) + 0
        --           ELSE
        --    (ROW_NUMBER() OVER (PARTITION BY DI.Key1, R.ReceiptKey ORDER BY DI.Key1, R.ReceiptKey) / 8) + 1
        --       END AS picturenumber,
        R.CarrierReference AS [BL Number],
        CONVERT(VARCHAR, R.ReceiptDate, 111) AS [Receipt Date],
        DI.Key1 AS [Container#],
        R.ReceiptKey AS [ASN#],
        Main.Remarks AS [Remarks],
        CONCAT(@c_BasePath_Win, DI.StorerKey, '\IN\', DI.Key1, '_', DI.Key2, '\', DI.Key1, '_', DI.Key2, '_', [Value]) AS [ImgPath_Win],
        CONCAT(@c_BasePath_Linux, DI.StorerKey, '/IN/', DI.Key1, '_', DI.Key2, '/', DI.Key1, '_', DI.Key2, '_', [Value]) AS [ImgPath_Linux]
    FROM dbo.V_DocInfo DI WITH (NOLOCK)
        INNER JOIN dbo.V_RECEIPT R WITH (NOLOCK)
            ON DI.StorerKey = R.StorerKey
               --AND DI.Key1 = R.ContainerKey
               AND DI.Key2 = R.ReceiptKey
        CROSS APPLY
        OPENJSON(DI.[Data])
        WITH
        (
            Remarks NVARCHAR(2000) '$.col15',
            ListImageName NVARCHAR(MAX) '$.ListImageName' AS JSON
        ) AS Main
        CROSS APPLY OPENJSON(Main.ListImageName)
    WHERE R.CarrierReference = @c_Key1
          --DI.Key1 = @c_Key2
          --AND DI.Key2 = @c_Key1
          --AND DI.StorerKey = @c_StorerKey
          AND DI.TableName = @c_TableName;

END; --End Stored Procedure

GO