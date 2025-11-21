SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_WebAPI_ImgProcUploadDocInfo                  */
/* Creation Date: 28-Jul-2021                                           */
/* Copyright: IDS                                                       */
/* Written by: GuanHaoChan                                              */
/*                                                                      */
/* Purpose: ImageProcessor OR PhotoRepo Insert/Update DocInfo.          */
/*                                                                      */
/* Input Parameters:  @b_Debug            - 0                           */
/*                    @c_Format           - 'XML/JSON'                  */
/*                    @c_UserID           - 'UserName'                  */
/*                    @c_OperationType    - 'Operation'                 */
/*                    @c_RequestString    - ''                          */
/*                    @b_Debug            - 0                           */
/*                                                                      */
/* Output Parameters: @b_Success          - Success Flag    = 0         */
/*                    @c_ErrNo            - Error No        = 0         */
/*                    @c_ErrMsg           - Error Message   = ''        */
/*                    @c_ResponseString   - ResponseString  = ''        */
/*                                                                      */
/* Called By: ImageProcessor OR PhotoRepo - isp_Generic_WebAPI_Request  */
/*                                                                      */
/* PVCS Version: -                                                      */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Purposes														*/
/* 2021-Jul-02 GHChan   Initial                                         */
/************************************************************************/
CREATE PROC [dbo].[isp_WebAPI_ImgProcUploadDocInfo]
(
    @b_Debug INT = 0,
    @c_Format VARCHAR(10) = '',
    @c_UserID NVARCHAR(256) = '',
    @c_OperationType NVARCHAR(60) = '',
    @c_RequestString NVARCHAR(MAX) = '',
    @b_Success INT = 0 OUTPUT,
    @n_ErrNo INT = 0 OUTPUT,
    @c_ErrMsg NVARCHAR(250) = '' OUTPUT,
    @c_ResponseString NVARCHAR(MAX) = '' OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET ANSI_DEFAULTS OFF;
    SET QUOTED_IDENTIFIER OFF;
    SET CONCAT_NULL_YIELDS_NULL OFF;

    DECLARE @n_Continue INT,
            @n_StartCnt INT,
            @c_ExecStatements NVARCHAR(MAX),
            @c_ExecArguments NVARCHAR(2000),
            @x_xml XML,
            @n_doc INT,
            @c_XMLRequestString NVARCHAR(MAX),
            @c_col1 NVARCHAR(100),
            @c_col2 NVARCHAR(100),
            @c_col3 NVARCHAR(100),
            @c_col4 NVARCHAR(100),
            @c_col5 NVARCHAR(100),
            @c_col6 NVARCHAR(100),
            @c_col7 NVARCHAR(100),
            @c_col8 NVARCHAR(100),
            @c_col9 NVARCHAR(100),
            @c_col10 NVARCHAR(100),
            @c_col11 NVARCHAR(100),
            @c_col12 NVARCHAR(100),
            @c_col13 NVARCHAR(100),
            @c_col14 NVARCHAR(100),
            @c_col15 NVARCHAR(2000),
            @b_ViewAction BIT,
            @c_ImgName NVARCHAR(100),
            @n_ActionFlag INT,
            @n_RecordID INT,
            @c_StorerKey NVARCHAR(15),
            @c_TableName NVARCHAR(20),
            @c_Key1 NVARCHAR(20),
            @c_Key2 NVARCHAR(20),
            @c_Key3 NVARCHAR(20),
            @n_LineSeq INT,
            @c_Data NVARCHAR(2000),
            @c_ListImageName NVARCHAR(2000),
            @c_SPName NVARCHAR(100);


    --DECLARE @tempJson TABLE
    --(
    --    --RowRef            INT IDENTITY(1,1) NOT NULL
    --    ContainerNumber NVARCHAR(30) NULL,
    --    DefectCode NVARCHAR(50) NULL,
    --    DefectQty NVARCHAR(10) NULL,
    --    Remarks NVARCHAR(2000) NULL,
    --    ImageName NVARCHAR(100) NULL
    --);

    DECLARE @tempJson TABLE
    (
        --RowRef            INT IDENTITY(1,1) NOT NULL
        col1 NVARCHAR(100) NULL
            DEFAULT '',
        col2 NVARCHAR(100) NULL
            DEFAULT '',
        col3 NVARCHAR(100) NULL
            DEFAULT '',
        col4 NVARCHAR(100) NULL
            DEFAULT '',
        col5 NVARCHAR(100) NULL
            DEFAULT '',
        col6 NVARCHAR(100) NULL
            DEFAULT '',
        col7 NVARCHAR(100) NULL
            DEFAULT '',
        col8 NVARCHAR(100) NULL
            DEFAULT '',
        col9 NVARCHAR(100) NULL
            DEFAULT '',
        col10 NVARCHAR(100) NULL
            DEFAULT '',
        col11 NVARCHAR(100) NULL
            DEFAULT '',
        col12 NVARCHAR(100) NULL
            DEFAULT '',
        col13 NVARCHAR(100) NULL
            DEFAULT '',
        col14 NVARCHAR(100) NULL
            DEFAULT '',
        col15 NVARCHAR(2000) NULL
            DEFAULT '',
        ImageName NVARCHAR(100) NULL
    );

    SET @n_Continue = 1;
    SET @n_StartCnt = @@TRANCOUNT;
    SET @b_Success = 1;
    SET @n_ErrNo = 0;
    SET @c_ErrMsg = '';
    SET @c_ResponseString = '';
    SET @c_XMLRequestString = N'';

    SET @c_col1 = N'';
    SET @c_col2 = N'';
    SET @c_col3 = N'';
    SET @c_col4 = N'';
    SET @c_col5 = N'';
    SET @c_col6 = N'';
    SET @c_col7 = N'';
    SET @c_col8 = N'';
    SET @c_col9 = N'';
    SET @c_col10 = N'';
    SET @c_col11 = N'';
    SET @c_col12 = N'';
    SET @c_col13 = N'';
    SET @c_col14 = N'';
    SET @c_col15 = N'';

    SET @b_ViewAction = 1;
    SET @c_ImgName = N'';

    SET @n_ActionFlag = 0; -- 1 == INSERT ; 2 == UPDATE

    SET @n_RecordID = 0;
    SET @c_StorerKey = N'';
    SET @c_TableName = N'IMPR_';
    SET @c_Key1 = N'';
    SET @c_Key2 = N'';
    SET @c_Key3 = N'';
    SET @n_LineSeq = 0;
    SET @c_Data = N'';
    SET @c_ListImageName = N'';

    IF ISNULL(RTRIM(@c_RequestString), '') = ''
    BEGIN
        SET @n_Continue = 3;
        SET @n_ErrNo = 97001;
        SET @c_ErrMsg = 'Content Body cannot be blank.';
        GOTO QUIT;
    END;

    SET @x_xml = CONVERT(XML, @c_RequestString);

    BEGIN TRAN;

    STEP_1:
    IF @n_Continue = 1
    BEGIN
        EXEC sp_xml_preparedocument @n_doc OUTPUT, @x_xml;

        --Read data from XML
        SELECT @c_col1 = ISNULL(RTRIM(col1), ''),
               @c_col2 = ISNULL(RTRIM(col2), ''),
               @c_col3 = ISNULL(RTRIM(col3), ''),
               @c_col4 = ISNULL(RTRIM(col4), ''),
               @c_col5 = ISNULL(RTRIM(col5), ''),
               @c_col6 = ISNULL(RTRIM(col6), ''),
               @c_col7 = ISNULL(RTRIM(col7), ''),
               @c_col8 = ISNULL(RTRIM(col8), ''),
               @c_col9 = ISNULL(RTRIM(col9), ''),
               @c_col10 = ISNULL(RTRIM(col10), ''),
               @c_col11 = ISNULL(RTRIM(col11), ''),
               @c_col12 = ISNULL(RTRIM(col12), ''),
               @c_col13 = ISNULL(RTRIM(col13), ''),
               @c_col14 = ISNULL(RTRIM(col14), ''),
               @c_col15 = ISNULL(RTRIM(col15), ''),
               @b_ViewAction = ViewAction,
               @c_ImgName = ISNULL(RTRIM(ImgName), '')
        FROM
            OPENXML(@n_doc, 'Request/Data', 1)
            WITH
            (
                col1 NVARCHAR(100) 'col1',
                col2 NVARCHAR(100) 'col2',
                col3 NVARCHAR(100) 'col3',
                col4 NVARCHAR(100) 'col4',
                col5 NVARCHAR(100) 'col5',
                col6 NVARCHAR(100) 'col6',
                col7 NVARCHAR(100) 'col7',
                col8 NVARCHAR(100) 'col8',
                col9 NVARCHAR(100) 'col9',
                col10 NVARCHAR(100) 'col10',
                col11 NVARCHAR(100) 'col11',
                col12 NVARCHAR(100) 'col12',
                col13 NVARCHAR(100) 'col13',
                col14 NVARCHAR(100) 'col14',
                col15 NVARCHAR(2000) 'col15',
                ViewAction BIT 'ViewAction',
                ImgName NVARCHAR(100) 'ImgName'
            );

        EXEC sp_xml_removedocument @n_doc;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.STORER WITH (NOLOCK)
            WHERE StorerKey = @c_col1
        )
        BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 97003;
            SET @c_ErrMsg = 'Invalid StorerKey[' + @c_col1 + ']';
            GOTO QUIT;
        END;

        IF @c_col2 NOT IN ( 'SKU', 'INBOUND', 'OUTBOUND', 'INBOUND_DAMAGE', 'DAMAGE_BY_WAREHOUSE', 'RETURN',
                            'COPACK(KITTING)', 'KIT_DAMAGE'
                          )
        BEGIN
            SET @n_Continue = 3;
            SET @n_ErrNo = 97002;
            SET @c_ErrMsg = 'Invalid SearchType[' + @c_col2 + ']..';
            GOTO QUIT;
        END;


        IF @c_col2 = 'SKU'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'SKU');
        END;
        ELSE IF @c_col2 = 'INBOUND'
                OR @c_col2 = 'RETURN'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'CONT_PO');
        END;
        ELSE IF @c_col2 = 'INBOUND_DAMAGE'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'CONT_PO_SKU');
        END;
        ELSE IF @c_col2 = 'OUTBOUND'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'CONT_ORD');
        END;
        ELSE IF @c_col2 = 'DAMAGE_BY_WAREHOUSE'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'TSFRKey');
        END;
        ELSE IF @c_col2 = 'COPACK(KITTING)'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'ORDKey');
        END;
        ELSE IF @c_col2 = 'KIT_DAMAGE'
        BEGIN
            SET @c_TableName = CONCAT(@c_TableName, 'KIT_SKU_LOT');
        END;



        SET @c_StorerKey = @c_col1;
        SET @c_Key1 = @c_col3;
        SET @c_Key2 = @c_col4;
        SET @c_Key3 = @c_col5;

        SELECT @n_RecordID = RecordID,
               @c_Data = ISNULL(RTRIM([Data]), '')
        FROM dbo.DocInfo WITH (NOLOCK)
        WHERE StorerKey = @c_StorerKey
              AND TableName = @c_TableName
              AND Key1 = @c_Key1
              AND Key2 = @c_Key2
              AND Key3 = @c_Key3;

        IF @b_ViewAction != 1
        BEGIN

            --IF EXISTS
            --(
            --    SELECT 1
            --    FROM dbo.CODELKUP WITH (NOLOCK)
            --    WHERE LISTNAME = 'IMGMGR'
            --          AND Code = @c_TableName
            --          AND Storerkey = @c_col1
            --)
            --BEGIN
            --    SELECT @c_SPName = UDF01
            --    FROM dbo.CODELKUP WITH (NOLOCK)
            --    WHERE LISTNAME = 'IMGMGR'
            --          AND Code = @c_TableName
            --          AND Storerkey = @c_col1;

            --    EXEC @c_SPName @b_Debug = @b_Debug,
            --                   @x_xml = @x_xml,
            --                   @b_Success = @b_Success OUTPUT,
            --                   @n_ErrNo = @n_ErrNo OUTPUT,
            --                   @c_ErrMsg = @c_ErrMsg OUTPUT;

            --    IF @b_Success <> 1
            --       OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
            --    BEGIN
            --        SET @b_Success = 0;
            --        GOTO QUIT;
            --    END;
            --END;

            IF @n_RecordID != 0
            BEGIN
                INSERT INTO @tempJson
                (
                    col1,
                    col2,
                    col3,
                    col4,
                    col5,
                    col6,
                    col7,
                    col8,
                    col9,
                    col10,
                    col11,
                    col12,
                    col13,
                    col14,
                    col15,
                    ImageName
                )
                SELECT Main.col1,
                       Main.col2,
                       ISNULL(RTRIM(Main.col3), ''),
                       ISNULL(RTRIM(Main.col4), ''),
                       ISNULL(RTRIM(Main.col5), ''),
                       ISNULL(RTRIM(Main.col6), ''),
                       ISNULL(RTRIM(Main.col7), ''),
                       ISNULL(RTRIM(Main.col8), ''),
                       ISNULL(RTRIM(Main.col9), ''),
                       ISNULL(RTRIM(Main.col10), ''),
                       ISNULL(RTRIM(Main.col11), ''),
                       ISNULL(RTRIM(Main.col12), ''),
                       ISNULL(RTRIM(Main.col13), ''),
                       ISNULL(RTRIM(Main.col14), ''),
                       ISNULL(RTRIM(Main.col15), ''),
                       [Value] AS ImageName
                FROM
                    OPENJSON(@c_Data)
                    WITH
                    (
                        col1 NVARCHAR(100) '$.col1',
                        col2 NVARCHAR(100) '$.col2',
                        col3 NVARCHAR(100) '$.col3',
                        col4 NVARCHAR(100) '$.col4',
                        col5 NVARCHAR(100) '$.col5',
                        col6 NVARCHAR(100) '$.col6',
                        col7 NVARCHAR(100) '$.col7',
                        col8 NVARCHAR(100) '$.col8',
                        col9 NVARCHAR(100) '$.col9',
                        col10 NVARCHAR(100) '$.col10',
                        col11 NVARCHAR(100) '$.col11',
                        col12 NVARCHAR(100) '$.col12',
                        col13 NVARCHAR(100) '$.col13',
                        col14 NVARCHAR(100) '$.col14',
                        col15 NVARCHAR(2000) '$.col15',
                        ListImageName NVARCHAR(MAX) '$.ListImageName' AS JSON
                    ) AS Main
                    CROSS APPLY OPENJSON(Main.ListImageName);
                IF EXISTS
                (
                    SELECT 1
                    FROM @tempJson
                    WHERE ISNULL(RTRIM(col1), '') = ISNULL(RTRIM(@c_col1), '')
                          AND ISNULL(RTRIM(col2), '') = ISNULL(RTRIM(@c_col2), '')
                          AND ISNULL(RTRIM(col3), '') = ISNULL(RTRIM(@c_col3), '')
                          AND ISNULL(RTRIM(col4), '') = ISNULL(RTRIM(@c_col4), '')
                          AND ISNULL(RTRIM(col5), '') = ISNULL(RTRIM(@c_col5), '')
                          AND ISNULL(RTRIM(col6), '') = ISNULL(RTRIM(@c_col6), '')
                          AND ISNULL(RTRIM(col7), '') = ISNULL(RTRIM(@c_col7), '')
                --AND col8 = @c_col8
                --AND col9 = @c_col9
                --AND col10 = @c_col10
                --AND col11 = @c_col11
                --AND col12 = @c_col12
                --AND col13 = @c_col13
                --AND col14 = @c_col14
                )
                BEGIN
                    IF @c_ImgName <> ''
                    BEGIN
                        INSERT INTO @tempJson
                        (
                            col1,
                            col2,
                            col3,
                            col4,
                            col5,
                            col6,
                            col7,
                            col8,
                            col9,
                            col10,
                            col11,
                            col12,
                            col13,
                            col14,
                            col15,
                            ImageName
                        )
                        VALUES
                        (   @c_col1,   -- col1 - nvarchar(100)
                            @c_col2,   -- col2 - nvarchar(100)
                            @c_col3,   -- col3 - nvarchar(100)
                            @c_col4,   -- col4 - nvarchar(100)
                            @c_col5,   -- col5 - nvarchar(100)
                            @c_col6,   -- col6 - nvarchar(100)
                            @c_col7,   -- col7 - nvarchar(100)
                            @c_col8,   -- col8 - nvarchar(100)
                            @c_col9,   -- col9 - nvarchar(100)
                            @c_col10,  -- col10 - nvarchar(100)
                            @c_col11,  -- col11 - nvarchar(100)
                            @c_col12,  -- col12 - nvarchar(100)
                            @c_col13,  -- col13 - nvarchar(100)
                            @c_col14,  -- col14 - nvarchar(100)
                            @c_col15,  -- col15 - nvarchar(2000)
                            @c_ImgName -- ImageName - nvarchar(100)
                            );
                    END;

                    UPDATE @tempJson
                    SET
                        --col8 = @c_col8,
                        --col9 = @c_col9,
                        --col10 = @c_col10,
                        --col11 = @c_col11,
                        --col12 = @c_col12,
                        --col13 = @c_col13,
                        --col14 = @c_col14,
                        col15 = @c_col15
                    WHERE ISNULL(RTRIM(col1), '') = ISNULL(RTRIM(@c_col1), '')
                          AND ISNULL(RTRIM(col2), '') = ISNULL(RTRIM(@c_col2), '')
                          AND ISNULL(RTRIM(col3), '') = ISNULL(RTRIM(@c_col3), '')
                          AND ISNULL(RTRIM(col4), '') = ISNULL(RTRIM(@c_col4), '')
                          AND ISNULL(RTRIM(col5), '') = ISNULL(RTRIM(@c_col5), '')
                          AND ISNULL(RTRIM(col6), '') = ISNULL(RTRIM(@c_col6), '')
                          AND ISNULL(RTRIM(col7), '') = ISNULL(RTRIM(@c_col7), '');
                --AND col8 = @c_col8
                --AND col9 = @c_col9
                --AND col10 = @c_col10
                --AND col11 = @c_col11
                --AND col12 = @c_col12
                --AND col13 = @c_col13
                --AND col14 = @c_col14;
                END;
                ELSE
                BEGIN

                    IF EXISTS
                    (
                        SELECT 1
                        FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'IMGMGR'
                              AND Code = @c_TableName
                              AND Storerkey = @c_col1
                    )
                    BEGIN
                        SELECT @c_SPName = UDF01
                        FROM dbo.CODELKUP WITH (NOLOCK)
                        WHERE LISTNAME = 'IMGMGR'
                              AND Code = @c_TableName
                              AND Storerkey = @c_col1;

                        EXEC @c_SPName @b_Debug = @b_Debug,
                                       @x_xml = @x_xml,
                                       @b_Success = @b_Success OUTPUT,
                                       @n_ErrNo = @n_ErrNo OUTPUT,
                                       @c_ErrMsg = @c_ErrMsg OUTPUT;

                        IF @b_Success <> 1
                           OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
                        BEGIN
                            SET @b_Success = 0;
                            GOTO QUIT;
                        END;
                    END;

                    IF @c_ImgName = ''
                    BEGIN
                        GOTO QUIT;
                    END;
                    INSERT INTO @tempJson
                    (
                        col1,
                        col2,
                        col3,
                        col4,
                        col5,
                        col6,
                        col7,
                        col8,
                        col9,
                        col10,
                        col11,
                        col12,
                        col13,
                        col14,
                        col15,
                        ImageName
                    )
                    VALUES
                    (   @c_col1,   -- col1 - nvarchar(100)
                        @c_col2,   -- col2 - nvarchar(100)
                        @c_col3,   -- col3 - nvarchar(100)
                        @c_col4,   -- col4 - nvarchar(100)
                        @c_col5,   -- col5 - nvarchar(100)
                        @c_col6,   -- col6 - nvarchar(100)
                        @c_col7,   -- col7 - nvarchar(100)
                        @c_col8,   -- col8 - nvarchar(100)
                        @c_col9,   -- col9 - nvarchar(100)
                        @c_col10,  -- col10 - nvarchar(100)
                        @c_col11,  -- col11 - nvarchar(100)
                        @c_col12,  -- col12 - nvarchar(100)
                        @c_col13,  -- col13 - nvarchar(100)
                        @c_col14,  -- col14 - nvarchar(100)
                        @c_col15,  -- col15 - nvarchar(2000)
                        @c_ImgName -- ImageName - nvarchar(100)
                        );
                END;

                SET @c_Data =
                (
                    SELECT t2.col1,
                           t2.col2,
                           CASE
                               WHEN t2.col3 = '' THEN
                                   NULL
                               ELSE
                                   t2.col3
                           END AS col3,
                           CASE
                               WHEN t2.col4 = '' THEN
                                   NULL
                               ELSE
                                   t2.col4
                           END AS col4,
                           CASE
                               WHEN t2.col5 = '' THEN
                                   NULL
                               ELSE
                                   t2.col5
                           END AS col5,
                           CASE
                               WHEN t2.col6 = '' THEN
                                   NULL
                               ELSE
                                   t2.col6
                           END AS col6,
                           CASE
                               WHEN t2.col7 = '' THEN
                                   NULL
                               ELSE
                                   t2.col7
                           END AS col7,
                           CASE
                               WHEN t2.col8 = '' THEN
                                   NULL
                               ELSE
                                   t2.col8
                           END AS col8,
                           CASE
                               WHEN t2.col9 = '' THEN
                                   NULL
                               ELSE
                                   t2.col9
                           END AS col9,
                           CASE
                               WHEN t2.col10 = '' THEN
                                   NULL
                               ELSE
                                   t2.col10
                           END AS col10,
                           CASE
                               WHEN t2.col11 = '' THEN
                                   NULL
                               ELSE
                                   t2.col11
                           END AS col11,
                           CASE
                               WHEN t2.col12 = '' THEN
                                   NULL
                               ELSE
                                   t2.col12
                           END AS col12,
                           CASE
                               WHEN t2.col13 = '' THEN
                                   NULL
                               ELSE
                                   t2.col13
                           END AS col13,
                           CASE
                               WHEN t2.col14 = '' THEN
                                   NULL
                               ELSE
                                   t2.col14
                           END AS col14,
                           CASE
                               WHEN t2.col15 = '' THEN
                                   NULL
                               ELSE
                                   t2.col15
                           END AS col15,
                           JSON_QUERY('[' + STUFF(
                                            (
                                                SELECT ',' + '"' + ImageName + '"'
                                                FROM @tempJson t1
                                                WHERE ISNULL(RTRIM(t1.col1), '') = ISNULL(RTRIM(t2.col1), '')
                                                      AND ISNULL(RTRIM(t1.col2), '') = ISNULL(RTRIM(t2.col2), '')
                                                      AND ISNULL(RTRIM(t1.col3), '') = ISNULL(RTRIM(t2.col3), '')
                                                      AND ISNULL(RTRIM(t1.col4), '') = ISNULL(RTRIM(t2.col4), '')
                                                      AND ISNULL(RTRIM(t1.col5), '') = ISNULL(RTRIM(t2.col5), '')
                                                      AND ISNULL(RTRIM(t1.col6), '') = ISNULL(RTRIM(t2.col6), '')
                                                      AND ISNULL(RTRIM(t1.col7), '') = ISNULL(RTRIM(t2.col7), '')
                                                      AND ISNULL(RTRIM(t1.col8), '') = ISNULL(RTRIM(t2.col8), '')
                                                      AND ISNULL(RTRIM(t1.col9), '') = ISNULL(RTRIM(t2.col9), '')
                                                      AND ISNULL(RTRIM(t1.col10), '') = ISNULL(RTRIM(t2.col10), '')
                                                      AND ISNULL(RTRIM(t1.col11), '') = ISNULL(RTRIM(t2.col11), '')
                                                      AND ISNULL(RTRIM(t1.col12), '') = ISNULL(RTRIM(t2.col12), '')
                                                      AND ISNULL(RTRIM(t1.col13), '') = ISNULL(RTRIM(t2.col13), '')
                                                      AND ISNULL(RTRIM(t1.col14), '') = ISNULL(RTRIM(t2.col14), '')
                                                      AND ISNULL(RTRIM(t1.col15), '') = ISNULL(RTRIM(t2.col15), '')
                                                FOR XML PATH('')
                                            ),
                                            1,
                                            1,
                                            ''
                                                 ) + ']'
                                     ) AS [ListImageName]
                    FROM @tempJson t2
                    GROUP BY t2.col1,
                             t2.col2,
                             t2.col3,
                             t2.col4,
                             t2.col5,
                             t2.col6,
                             t2.col7,
                             t2.col8,
                             t2.col9,
                             t2.col10,
                             t2.col11,
                             t2.col12,
                             t2.col13,
                             t2.col14,
                             t2.col15
                    FOR JSON AUTO
                );

                UPDATE dbo.DocInfo WITH (ROWLOCK)
                SET [Data] = @c_Data
                WHERE RecordID = @n_RecordID;
            END;
            ELSE
            BEGIN

                IF EXISTS
                (
                    SELECT 1
                    FROM dbo.CODELKUP WITH (NOLOCK)
                    WHERE LISTNAME = 'IMGMGR'
                          AND Code = @c_TableName
                          AND Storerkey = @c_col1
                )
                BEGIN
                    SELECT @c_SPName = UDF01
                    FROM dbo.CODELKUP WITH (NOLOCK)
                    WHERE LISTNAME = 'IMGMGR'
                          AND Code = @c_TableName
                          AND Storerkey = @c_col1;

                    EXEC @c_SPName @b_Debug = @b_Debug,
                                   @x_xml = @x_xml,
                                   @b_Success = @b_Success OUTPUT,
                                   @n_ErrNo = @n_ErrNo OUTPUT,
                                   @c_ErrMsg = @c_ErrMsg OUTPUT;

                    IF @b_Success <> 1
                       OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
                    BEGIN
                        SET @b_Success = 0;
                        GOTO QUIT;
                    END;
                END;

                INSERT INTO @tempJson
                (
                    col1,
                    col2,
                    col3,
                    col4,
                    col5,
                    col6,
                    col7,
                    col8,
                    col9,
                    col10,
                    col11,
                    col12,
                    col13,
                    col14,
                    col15,
                    ImageName
                )
                VALUES
                (   @c_col1,   -- col1 - nvarchar(100)
                    @c_col2,   -- col2 - nvarchar(100)
                    @c_col3,   -- col3 - nvarchar(100)
                    @c_col4,   -- col4 - nvarchar(100)
                    @c_col5,   -- col5 - nvarchar(100)
                    @c_col6,   -- col6 - nvarchar(100)
                    @c_col7,   -- col7 - nvarchar(100)
                    @c_col8,   -- col8 - nvarchar(100)
                    @c_col9,   -- col9 - nvarchar(100)
                    @c_col10,  -- col10 - nvarchar(100)
                    @c_col11,  -- col11 - nvarchar(100)
                    @c_col12,  -- col12 - nvarchar(100)
                    @c_col13,  -- col13 - nvarchar(100)
                    @c_col14,  -- col14 - nvarchar(100)
                    @c_col15,  -- col15 - nvarchar(2000)
                    @c_ImgName -- ImageName - nvarchar(100)
                    );

                SET @c_Data =
                (
                    SELECT t2.col1,
                           t2.col2,
                           CASE
                               WHEN t2.col3 = '' THEN
                                   NULL
                               ELSE
                                   t2.col3
                           END AS col3,
                           CASE
                               WHEN t2.col4 = '' THEN
                                   NULL
                               ELSE
                                   t2.col4
                           END AS col4,
                           CASE
                               WHEN t2.col5 = '' THEN
                                   NULL
                               ELSE
                                   t2.col5
                           END AS col5,
                           CASE
                               WHEN t2.col6 = '' THEN
                                   NULL
                               ELSE
                                   t2.col6
                           END AS col6,
                           CASE
                               WHEN t2.col7 = '' THEN
                                   NULL
                               ELSE
                                   t2.col7
                           END AS col7,
                           CASE
                               WHEN t2.col8 = '' THEN
                                   NULL
                               ELSE
                                   t2.col8
                           END AS col8,
                           CASE
                               WHEN t2.col9 = '' THEN
                                   NULL
                               ELSE
                                   t2.col9
                           END AS col9,
                           CASE
                               WHEN t2.col10 = '' THEN
                                   NULL
                               ELSE
                                   t2.col10
                           END AS col10,
                           CASE
                               WHEN t2.col11 = '' THEN
                                   NULL
                               ELSE
                                   t2.col11
                           END AS col11,
                           CASE
                               WHEN t2.col12 = '' THEN
                                   NULL
                               ELSE
                                   t2.col12
                           END AS col12,
                           CASE
                               WHEN t2.col13 = '' THEN
                                   NULL
                               ELSE
                                   t2.col13
                           END AS col13,
                           CASE
                               WHEN t2.col14 = '' THEN
                                   NULL
                               ELSE
                                   t2.col14
                           END AS col14,
                           CASE
                               WHEN t2.col15 = '' THEN
                                   NULL
                               ELSE
                                   t2.col15
                           END AS col15,
                           JSON_QUERY('[' + STUFF(
                                            (
                                                SELECT ',' + '"' + ImageName + '"'
                                                FROM @tempJson t1
                                                WHERE ISNULL(RTRIM(t1.col1), '') = ISNULL(RTRIM(t2.col1), '')
                                                      AND ISNULL(RTRIM(t1.col2), '') = ISNULL(RTRIM(t2.col2), '')
                                                      AND ISNULL(RTRIM(t1.col3), '') = ISNULL(RTRIM(t2.col3), '')
                                                      AND ISNULL(RTRIM(t1.col4), '') = ISNULL(RTRIM(t2.col4), '')
                                                      AND ISNULL(RTRIM(t1.col5), '') = ISNULL(RTRIM(t2.col5), '')
                                                      AND ISNULL(RTRIM(t1.col6), '') = ISNULL(RTRIM(t2.col6), '')
                                                      AND ISNULL(RTRIM(t1.col7), '') = ISNULL(RTRIM(t2.col7), '')
                                                      AND ISNULL(RTRIM(t1.col8), '') = ISNULL(RTRIM(t2.col8), '')
                                                      AND ISNULL(RTRIM(t1.col9), '') = ISNULL(RTRIM(t2.col9), '')
                                                      AND ISNULL(RTRIM(t1.col10), '') = ISNULL(RTRIM(t2.col10), '')
                                                      AND ISNULL(RTRIM(t1.col11), '') = ISNULL(RTRIM(t2.col11), '')
                                                      AND ISNULL(RTRIM(t1.col12), '') = ISNULL(RTRIM(t2.col12), '')
                                                      AND ISNULL(RTRIM(t1.col13), '') = ISNULL(RTRIM(t2.col13), '')
                                                      AND ISNULL(RTRIM(t1.col14), '') = ISNULL(RTRIM(t2.col14), '')
                                                      AND ISNULL(RTRIM(t1.col15), '') = ISNULL(RTRIM(t2.col15), '')
                                                FOR XML PATH('')
                                            ),
                                            1,
                                            1,
                                            ''
                                                 ) + ']'
                                     ) AS [ListImageName]
                    FROM @tempJson t2
                    GROUP BY t2.col1,
                             t2.col2,
                             t2.col3,
                             t2.col4,
                             t2.col5,
                             t2.col6,
                             t2.col7,
                             t2.col8,
                             t2.col9,
                             t2.col10,
                             t2.col11,
                             t2.col12,
                             t2.col13,
                             t2.col14,
                             t2.col15
                    FOR JSON AUTO
                );

                INSERT INTO dbo.DocInfo
                (
                    TableName,
                    Key1,
                    Key2,
                    Key3,
                    StorerKey,
                    LineSeq,
                    [Data],
                    DataType
                )
                VALUES
                (@c_TableName, @c_Key1, @c_Key2, @c_Key3, @c_StorerKey, @n_LineSeq, @c_Data, 'STRING');

                SELECT @n_RecordID = SCOPE_IDENTITY();
            END;
        END;
        ELSE
        BEGIN
            IF @n_RecordID != 0
            BEGIN
                INSERT INTO @tempJson
                (
                    col1,
                    col2,
                    col3,
                    col4,
                    col5,
                    col6,
                    col7,
                    col8,
                    col9,
                    col10,
                    col11,
                    col12,
                    col13,
                    col14,
                    col15,
                    ImageName
                )
                SELECT Main.col1,
                       Main.col2,
                       ISNULL(RTRIM(Main.col3), ''),
                       ISNULL(RTRIM(Main.col4), ''),
                       ISNULL(RTRIM(Main.col5), ''),
                       ISNULL(RTRIM(Main.col6), ''),
                       ISNULL(RTRIM(Main.col7), ''),
                       ISNULL(RTRIM(Main.col8), ''),
                       ISNULL(RTRIM(Main.col9), ''),
                       ISNULL(RTRIM(Main.col10), ''),
                       ISNULL(RTRIM(Main.col11), ''),
                       ISNULL(RTRIM(Main.col12), ''),
                       ISNULL(RTRIM(Main.col13), ''),
                       ISNULL(RTRIM(Main.col14), ''),
                       ISNULL(RTRIM(Main.col15), ''),
                       [Value] AS ImageName
                FROM
                    OPENJSON(@c_Data)
                    WITH
                    (
                        col1 NVARCHAR(100) '$.col1',
                        col2 NVARCHAR(100) '$.col2',
                        col3 NVARCHAR(100) '$.col3',
                        col4 NVARCHAR(100) '$.col4',
                        col5 NVARCHAR(100) '$.col5',
                        col6 NVARCHAR(100) '$.col6',
                        col7 NVARCHAR(100) '$.col7',
                        col8 NVARCHAR(100) '$.col8',
                        col9 NVARCHAR(100) '$.col9',
                        col10 NVARCHAR(100) '$.col10',
                        col11 NVARCHAR(100) '$.col11',
                        col12 NVARCHAR(100) '$.col12',
                        col13 NVARCHAR(100) '$.col13',
                        col14 NVARCHAR(100) '$.col14',
                        col15 NVARCHAR(2000) '$.col15',
                        ListImageName NVARCHAR(MAX) '$.ListImageName' AS JSON
                    ) AS Main
                    CROSS APPLY OPENJSON(Main.ListImageName);
                IF NOT EXISTS
                (
                    SELECT 1
                    FROM @tempJson
                    WHERE col1 = @c_col1
                          AND col2 = @c_col2
                          AND col3 = @c_col3
                          AND col4 = @c_col4
                          AND col5 = @c_col5
                          AND col6 = @c_col6
                          AND col7 = @c_col7
                --AND col8 = @c_col8
                --AND col9 = @c_col9
                --AND col10 = @c_col10
                --AND col11 = @c_col11
                --AND col12 = @c_col12
                --AND col13 = @c_col13
                --AND col14 = @c_col14
                )
                BEGIN
                    SET @n_RecordID = 0;
                END;
            END;
        END;

    END;

    IF @n_RecordID = 0
    BEGIN
        --SET @n_Continue = 3 
        SET @n_ErrNo = 97012;
        SET @c_ErrMsg = 'No records found!';
        GOTO QUIT;
    END;

    QUIT:
    IF @n_Continue = 3 -- Error Occured - Process And Return      
    BEGIN
        SET @b_Success = 0;
        IF @@TRANCOUNT > @n_StartCnt
           AND @@TRANCOUNT = 1
        BEGIN
            ROLLBACK TRAN;
        END;
        ELSE
        BEGIN
            WHILE @@TRANCOUNT > @n_StartCnt
            BEGIN
                COMMIT TRAN;
            END;
        END;
        RETURN;
    END;
    ELSE
    BEGIN
        SELECT @b_Success = 1;
        WHILE @@TRANCOUNT > @n_StartCnt
        BEGIN
            COMMIT TRAN;
        END;

        IF @n_RecordID <> 0
        BEGIN
            SELECT @c_Data = [Data]
            FROM dbo.DocInfo WITH (NOLOCK)
            WHERE RecordID = @n_RecordID;

            SET @c_ResponseString =
            (
                SELECT @n_RecordID AS RecordID,
                       col15 AS Remarks
                FROM
                    OPENJSON(@c_Data)
                    WITH
                    (
                        col1 NVARCHAR(100) '$.col1',
                        col2 NVARCHAR(100) '$.col2',
                        col3 NVARCHAR(100) '$.col3',
                        col4 NVARCHAR(100) '$.col4',
                        col5 NVARCHAR(100) '$.col5',
                        col6 NVARCHAR(100) '$.col6',
                        col7 NVARCHAR(100) '$.col7',
                        col8 NVARCHAR(100) '$.col8',
                        col9 NVARCHAR(100) '$.col9',
                        col10 NVARCHAR(100) '$.col10',
                        col11 NVARCHAR(100) '$.col11',
                        col12 NVARCHAR(100) '$.col12',
                        col13 NVARCHAR(100) '$.col13',
                        col14 NVARCHAR(100) '$.col14',
                        col15 NVARCHAR(2000) '$.col15',
                        ListImageName NVARCHAR(MAX) '$.ListImageName' AS JSON
                    ) AS Main
                    CROSS APPLY OPENJSON(Main.ListImageName)
                WHERE ISNULL(RTRIM(col1), '') = ISNULL(RTRIM(@c_col1), '')
                      AND ISNULL(RTRIM(col2), '') = ISNULL(RTRIM(@c_col2), '')
                      AND ISNULL(RTRIM(col3), '') = ISNULL(RTRIM(@c_col3), '')
                      AND ISNULL(RTRIM(col4), '') = ISNULL(RTRIM(@c_col4), '')
                      AND ISNULL(RTRIM(col5), '') = ISNULL(RTRIM(@c_col5), '')
                      AND ISNULL(RTRIM(col6), '') = ISNULL(RTRIM(@c_col6), '')
                      AND ISNULL(RTRIM(col7), '') = ISNULL(RTRIM(@c_col7), '')
                GROUP BY Main.col15
                FOR XML PATH('')
            );
        END;

        RETURN;
    END;
END; -- Procedure  

GO