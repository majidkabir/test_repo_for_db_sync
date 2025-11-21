SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 

/*------------------------------------------------------------------------------------------------------------ */
/*                                                                                                             */
/*Stored Procedure: isp_UpdateSplitOrders_UDF04_02                                                             */
/* Creation Date: 09-October-2020                                                                              */
/* Copyright: LF LOGISTICS                                                                                     */
/* Written by: JoshYan                                                                                         */
/*                                                                                                             */
/* Purpose: https://jira.lfapps.net/browse/WMS-                                                                */
/*                                                                                                             */
/* Called By:                                                                                                  */
/*                                                                                                             */
/* Parameters:                                                                                                 */
/*                                                                                                             */
/* PVCS Version:                                                                                               */
/*                                                                                                             */
/* Version:                                                                                                    */
/*                                                                                                             */
/* Data Modifications:                                                                                         */
/*                                                                                                             */
/* Updates:                                                                                                    */
/* Date         Author  Ver. Purposes                                                                          */
/* 09-Oct-2020  JoshYan 1.0  Split original order Orders.UserDefine04 map to split orders Orders.UserDefine04  */
/* 19-Oct-2020  JoshYan 1.1  Update assign tracking# process since Courier API will return 2 tracking# in same col*/
/* ------------------------------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[isp_UpdateSplitOrders_UDF04_02] (
@c_StorerKey NVARCHAR(15),
@b_debug BIT = 0)
AS
SET NOCOUNT ON;
SET ANSI_NULLS OFF;
SET QUOTED_IDENTIFIER OFF;
SET CONCAT_NULL_YIELDS_NULL OFF;

BEGIN

    DECLARE @c_OriginalOrderKey   NVARCHAR(20),
            @c_OriginalTrackingNo NVARCHAR(40),
            @c_SplitOrderKey      NVARCHAR(15),
            @c_SplitTrackingNo    NVARCHAR(40),
            @c_SplitCarrierName   NVARCHAR(30),
            @c_SplitKeyName       NVARCHAR(30),
            @c_SplitOrderRow      INT,
            @n_err                INT,
            @c_errmsg             NVARCHAR(128);

    IF ISNULL(OBJECT_ID('tempdb..#Temp_FinalOrders'), '') <> ''
    BEGIN
        DROP TABLE #Temp_FinalOrders;
    END;

    CREATE TABLE #Temp_FinalOrders (OrderKey NVARCHAR(20),
                                    [Status] NVARCHAR(10),
                                    SOStatus NVARCHAR(10),
                                    OrderGroup NVARCHAR(20),
                                    Issued NVARCHAR(10));

    INSERT INTO #Temp_FinalOrders ([OrderKey],
                                   [Status],
                                   [SOStatus],
                                   [OrderGroup],
                                   [Issued])
    SELECT o.OrderKey,
           o.[Status],
           o.SOStatus,
           o.[OrderGroup],
           o.[Issued]
      FROM ORDERS AS o WITH (NOLOCK)
     WHERE o.StorerKey                 = @c_StorerKey
       AND TRY_CAST(o.[Status] AS INT) <= 5 -- prevent 'CANC' status        
       AND o.SOStatus                  = '0'
       AND o.OrderGroup                = 'ORI_ORDER'
       AND o.Issued                    = 'N'
       AND o.UserDefine04              <> ''
       AND o.TrackingNo                <> '';

    IF NOT EXISTS (SELECT 1 FROM #Temp_FinalOrders)
    BEGIN
        SET @c_errmsg = N' No columns acquire from ''#Temp_FinalOrders'' table. ';
        GOTO QUIT;
    END;

    IF EXISTS (SELECT 1 FROM #Temp_FinalOrders)
    BEGIN
        IF (@b_debug = 1)
        BEGIN
            SELECT 'Updating original orders UDF04 to split orders UDF04.';
            SELECT * FROM #Temp_FinalOrders;
            --SELECT TrackingNo, UserDefine04, SOStatus, Status, OrderGroup, Issued, * FROM ORDERS (NOLOCK) WHERE OrderKey = @c_NewOrderkey          
            --SELECT ConsoOrderKey FROM OrderDetail (NOLOCK) WHERE Orderkey = @c_NewOrderkey          
        END;

        DECLARE CUR_READ_UD04_SplitOrders CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
        SELECT orio.OrderKey,
               oriod.ConsoOrderKey,
               ROW_NUMBER() OVER (PARTITION BY orio.OrderKey ORDER BY oriod.ConsoOrderKey) AS OrderRow
          FROM #Temp_FinalOrders
          JOIN ORDERS AS orio WITH (NOLOCK)
            ON orio.OrderKey = #Temp_FinalOrders.[OrderKey]
          JOIN ORDERDETAIL AS oriod WITH (NOLOCK)
            ON orio.OrderKey = oriod.OrderKey
          JOIN ORDERS AS splo WITH (NOLOCK)
            ON splo.OrderKey = oriod.ConsoOrderKey
         WHERE orio.OrderGroup     = #Temp_FinalOrders.[OrderGroup]
           AND oriod.ConsoOrderKey <> ''
           AND splo.UserDefine04   = ''
         GROUP BY orio.OrderKey,oriod.ConsoOrderKey;

        OPEN CUR_READ_UD04_SplitOrders;
        FETCH NEXT FROM CUR_READ_UD04_SplitOrders
         INTO @c_OriginalOrderKey,
              @c_SplitOrderKey,
              @c_SplitOrderRow;

        WHILE (@@FETCH_STATUS <> -1)
        BEGIN

            SET @c_OriginalTrackingNo = N'';
            SET @c_SplitTrackingNo = N'';

            SELECT TOP 1 @c_OriginalTrackingNo = TrackingNo,
                         @c_SplitCarrierName = CarrierName,
                         @c_SplitKeyName = KeyName
              FROM CartonTrack WITH (NOLOCK)
             WHERE LabelNo = @c_OriginalOrderKey;

            SELECT @c_SplitTrackingNo = ISNULL(ColValue, '')
              FROM dbo.fnc_DelimSplit(',', @c_OriginalTrackingNo)
             WHERE SeqNo = @c_SplitOrderRow;

            IF (@b_debug = 1)
            BEGIN
                SELECT @c_OriginalOrderKey 'OriginalOrderKey',
                       @c_OriginalTrackingNo 'OriginalTrackingNo',
                       @c_SplitOrderKey 'Split ConsoOrderKey',
                       @c_SplitOrderRow 'SplitOrderRow',
                       @c_SplitTrackingNo 'Split TrackNo';
            END;

            IF (ISNULL(@c_SplitTrackingNo, '') <> '')
            BEGIN

                BEGIN TRAN;
                SET @n_err = 0;

                INSERT INTO dbo.CartonTrack (TrackingNo,
                                             CarrierName,
                                             KeyName,
                                             LabelNo,
                                             CarrierRef1,
                                             CarrierRef2,
                                             UDF01)
                VALUES (@c_SplitTrackingNo, -- TrackingNo - nvarchar(40)  
                        @c_SplitCarrierName, -- CarrierName - nvarchar(30)  
                        @c_SplitKeyName, -- KeyName - nvarchar(30)  
                        @c_SplitOrderKey, -- LabelNo - nvarchar(20)  
                        N'', -- CarrierRef1 - nvarchar(40)  
                        N'GET', -- CarrierRef2 - nvarchar(40)  
                        @c_OriginalOrderKey -- UDF01 - nvarchar(30)  
                    );

                IF @@ROWCOUNT = 0
                OR @@ERROR <> 0
                BEGIN
                    SET @n_err = 1;
                END;

                UPDATE [dbo].[ORDERS] WITH (ROWLOCK)
                   SET TrackingNo = @c_SplitTrackingNo,
                       UserDefine04 = @c_SplitTrackingNo,
                       M_Address2 = @c_OriginalTrackingNo,
                       [Issued] = 'Y',
                       TrafficCop = NULL,
                       EditDate = GETDATE(),
                       EditWho = SUSER_SNAME()
                 WHERE OrderKey  = @c_SplitOrderKey
                   AND StorerKey = @c_StorerKey;

                IF @@ROWCOUNT = 0
                OR @@ERROR <> 0
                BEGIN
                    SET @n_err = 2;
                END;

                IF (@c_SplitOrderRow = 1) --Update Original UDF04 to normal tracking#  
                BEGIN
                    UPDATE [dbo].[ORDERS] WITH (ROWLOCK)
                       SET TrackingNo = @c_SplitTrackingNo,
                           UserDefine04 = @c_SplitTrackingNo,
                           TrafficCop = NULL,
                           EditDate = GETDATE(),
                           EditWho = SUSER_SNAME()
                     WHERE OrderKey  = @c_OriginalOrderKey
                       AND StorerKey = @c_StorerKey;

                    IF @@ROWCOUNT = 0
                    OR @@ERROR <> 0
                    BEGIN
                        SET @n_err = 3;
                    END;
                END;

                IF (@c_SplitOrderRow = 2)
                BEGIN
                    UPDATE [dbo].[ORDERS] WITH (ROWLOCK)
                       SET [Issued] = 'Y',
                           [SOStatus] = 'HOLD',
                           TrafficCop = NULL,
                           EditDate = GETDATE(),
                           EditWho = SUSER_SNAME()
                     WHERE OrderKey  = @c_OriginalOrderKey
                       AND StorerKey = @c_StorerKey;

                    IF @@ROWCOUNT = 0
                    OR @@ERROR <> 0
                    BEGIN
                        SET @n_err = 4;
                    END;
                END;
                --ROLLBACK TRAN      

                IF @n_err <> 0
                BEGIN
                    ROLLBACK TRAN;
                    SET @c_errmsg = N'FAIL SPLTTING, Unable to update original orders UDF04 to split orders UDF04.';
                    GOTO QUIT;
                END;
                COMMIT TRAN;

            END;

            FETCH NEXT FROM CUR_READ_UD04_SplitOrders
             INTO @c_OriginalOrderKey,
                  @c_SplitOrderKey,
                  @c_SplitOrderRow;
        END; --WHILE (@@FETCH_STATUS <> -1)          
        CLOSE CUR_READ_UD04_SplitOrders;
        DEALLOCATE CUR_READ_UD04_SplitOrders;
    END;

    QUIT:
    IF (@b_debug = 1)
    BEGIN
        PRINT @n_err;
        PRINT @c_errmsg;
    END;
    IF CURSOR_STATUS('LOCAL', 'CUR_READ_UD04_SplitOrders') IN ( 0, 1 )
    BEGIN
        CLOSE CUR_READ_UD04_SplitOrders;
        DEALLOCATE CUR_READ_UD04_SplitOrders;
    END;

END;

GO