SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************************/
/* SP: ispOrderProcessingByPrePack                                           */
/* Creation Date:                                                            */
/* Copyright: IDS                                                            */
/* Written by: Shong                                                         */
/*                                                                           */
/* Purpose: Special Allocation Request by US Pe-Pack                         */
/*          Three scenarios:                                                 */
/*          1. No userDefine03, No Lottable01 & Lottable02                   */
/*          2. With userdefine03, no lottable 1 & 2                          */
/*          3. With userdefine03, and lottable 1 & 2                         */
/*                                                                           */
/* Usage:                                                                    */
/*                                                                           */
/* Called By: Power Builder Allocation from Load Plan                        */
/*                                                                           */
/* PVCS Version: 1.4                                                         */
/*                                                                           */
/* Version: 5.4                                                              */
/*                                                                           */
/* Data Modifications:                                                       */
/*                                                                           */
/* Updates:                                                                  */
/* Date         Author     Ver   Purposes                                    */
/* 08-Oct-2007  Vicky            - To make sure prepack doesnt get from Loose*/
/*                                 Location                                  */
/*                               - Change the sorting of location selection  */
/* 12-Oct-2007  Vicky            - Add Disticnt when count SKU (Vicky01)     */
/* 30-Oct-2007  Shong            - If OpenQty < Component Qty, then do not   */
/*                                 Allocate as pre-pack                      */
/* 04-Sep-2008  Shong      1.1   SOS110959 - Update BOMQty with Lottable05   */
/* 01-Feb-2010  SHONG      1.2   SOS160168 - TITAN BOM Packing Consolidated  */
/*                                           Allocation                      */
/* 25-Feb-2010  SHONG      1.2   Fixing the Devide by ZERO Error             */
/* 21-Apr-2010  LEONG      1.2   SOS# 167072 - Deduct QtyAllocated for       */
/*                                             @nOpenQty                     */
/* 22-Jun-2010  SHONG      1.3   SOS# 178548 - Resolved Null Packkey Issues  */
/* 25-Oct-2010  LEONG      1.4   SOS# 194063 - Deduct OrderDetail.QtyPicked  */
/* 27-Oct-2016  SHONG      1.5   Remove SET ROWCOUNT                         */
/*****************************************************************************/
CREATE PROC [dbo].[ispOrderProcessingByPrePack]
     @c_OrderKey     NVARCHAR(10)
   , @c_oskey        NVARCHAR(10)
   , @c_docarton     NVARCHAR(1)
   , @c_doroute      NVARCHAR(1)
   , @c_tblprefix    NVARCHAR(10)
   , @b_Success      INT        OUTPUT
   , @n_err          INT        OUTPUT
   , @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF   

    DECLARE @n_continue            INT
          , @n_starttcnt           INT -- Holds the current transaction count
          , @n_cnt                 INT -- Holds @@ROWCOUNT after certain operations
          , @c_preprocess          NVARCHAR(250) -- preprocess
          , @c_pstprocess          NVARCHAR(250) -- post process
          , @n_err2                INT -- For Additional Error Detection
          , @b_debug               INT -- Debug 0 - OFF, 1 - Show ALL, 2 - Map


    DECLARE @cStyle                NVARCHAR(20)
          , @cParentSKU            NVARCHAR(20)
          , @cPrePackIndicator     NVARCHAR(18)
          , @cComponentSKU         NVARCHAR(20)
          , @nNoOfComponents       INT
          , @bParentSKUFound       INT
          , @nComponentQty         INT
          , @nOpenQty              INT
          , @nBOMQty               INT
          , @cLOT                  NVARCHAR(10)
          , @cLOC                  NVARCHAR(10)
          , @cID                   NVARCHAR(18)
          , @nQtyToFullFill        INT
          , @cPrevPrePackIndicator NVARCHAR(18)
          , @cPrevOrderKey         NVARCHAR(10)
          , @nSortOrder            INT
          , @nQtyToProcess         INT
          , @nRatio                INT
          , @nParentSKUFound       INT

    SELECT @n_starttcnt = @@TRANCOUNT
         , @n_continue = 1
         , @b_Success = 0
         , @n_err = 0
         , @n_cnt = 0

    SELECT @c_errmsg = ''
         , @n_err2 = 0

    SELECT @b_debug = 0

    IF @c_tblprefix='DS1' OR @c_tblprefix='DS2'
    BEGIN
        SELECT @b_debug = CONVERT(INT ,RIGHT(@c_tblprefix ,1))
    END

    DECLARE @n_cnt_sql INT -- Additional holds for @@ROWCOUNT to try catch a wrong processing

    /* #INCLUDE <SPOP1.SQL> */

    IF @n_continue=1 OR @n_continue=2
    BEGIN
        IF (LTRIM(RTRIM(@c_oskey)) IS NULL OR LTRIM(RTRIM(@c_oskey))='')
        BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63500
            SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+
                   ': Invalid Parameters Passed (ispOrderProcessingByPrePack)'
        END
    END -- @n_continue =1 or @n_continue = 2

    ---- Start Here Case Pick
    DECLARE @cLottable01           NVARCHAR(18)
          , @cLottable02           NVARCHAR(18)
          , @dLottable04           DATETIME
          , @nQtyAvailable         INT
          , @nQty                  INT
          , @nQtyToTake            INT
          , @cOrderKey             NVARCHAR(10)
          , @cStorerKey            NVARCHAR(15)
          , @cOrderLineNumber      NVARCHAR(5)
          , @cSKU                  NVARCHAR(20)
          , @cPackKey              NVARCHAR(10)
          , @nCaseCnt              INT
          , @nPalletCnt            INT
          , @nInnerCnt             INT
          , @bAllocatePallet       INT
          , @nUOMBase              INT
          , @cFacility             NVARCHAR(5)
          , @cPickDetailKey        NVARCHAR(10)
          , @nBOMQtyToTake         INT
          , @cExecStatements       NVARCHAR(4000)

    DECLARE @cAllowOverAllocations NVARCHAR(1)

    -- Extra Step Version 2.0
    ------------------------------------------------------------------------------------------------
    DECLARE @cLottable03      NVARCHAR(18)
           ,@nPackSeq         INT

    DECLARE @t_AssignPrePack  TABLE
            (
                OrderKey         NVARCHAR(10)
               ,OrderLineNumber  NVARCHAR(5)
               ,StorerKey        NVARCHAR(15)
               ,SKU              NVARCHAR(20)
               ,Style            NVARCHAR(20)
               ,PrePackIndicator NVARCHAR(18)
               ,Lottable01       NVARCHAR(18)
               ,Lottable02       NVARCHAR(18)
               ,Lottable03       NVARCHAR(18)
               ,OpenQty          INT
            )

    SET @nPackSeq = 1

    INSERT INTO @t_AssignPrePack
    SELECT ORDERDETAIL.OrderKey
          ,ORDERDETAIL.OrderLineNumber
          ,ORDERDETAIL.StorerKey
          ,ORDERDETAIL.SKU
          ,SKU.Style
          ,ISNULL(ORDERDETAIL.UserDefine03 ,'')
          ,ISNULL(Lottable01 ,'')
          ,ISNULL(Lottable02 ,'')
          ,''
          ,OpenQty
    FROM   ORDERDETAIL(NOLOCK)
           JOIN SKU(NOLOCK)
                ON  SKU.StorerKey = ORDERDETAIL.StorerKey AND
                    SKU.SKU = OrderDetail.SKU
    WHERE  ORDERDETAIL.Status<'9' AND
          ORDERDETAIL.LoadKey = @c_oskey AND
           (
               ORDERDETAIL.UserDefine03 IS NULL OR
               ORDERDETAIL.UserDefine03=''
           ) AND
           (
               (
                   ORDERDETAIL.Lottable01 IS NOT NULL AND
                   ORDERDETAIL.Lottable01<>''
               ) OR
               (
                   ORDERDETAIL.Lottable02 IS NOT NULL AND
                   ORDERDETAIL.Lottable02<>''
               )
           )
    ORDER BY
           ORDERDETAIL.OrderKey
          ,ORDERDETAIL.OrderLineNumber

    WHILE 1=1
    BEGIN
        -- SET ROWCOUNT 1

        SET @cOrderKey = ''

        SELECT TOP 1
               @cOrderKey = OrderKey
              ,@cStorerKey = StorerKey
              ,@cOrderLineNumber = OrderLineNumber
              ,@cSKU = SKU
              ,@cStyle = Style
              ,@cLottable01 = ISNULL(Lottable01 ,'')
              ,@cLottable02 = ISNULL(Lottable02 ,'')
        FROM   @t_AssignPrePack
        WHERE  (PrePackIndicator IS NULL OR PrePackIndicator='')
        ORDER BY OrderKey, OrderLineNumber

        IF @cOrderKey='' OR @cOrderKey IS NULL
        BEGIN
            --SET ROWCOUNT 0
            BREAK
        END

        SET @cLottable03 = ''

        --SET ROWCOUNT 1

        SELECT TOP 1 
               @cLottable03 = Lottable03
        FROM   LOT WITH (NOLOCK)
               JOIN LotAttribute LA WITH (NOLOCK)
                    ON  LA.LOT = LOT.LOT
               JOIN SKU WITH (NOLOCK)
                    ON  SKU.StorerKey = LOT.StorerKey AND
                        SKU.SKU = LOT.SKU
        WHERE  LA.StorerKey = @cStorerKey AND
               LA.SKU = @cSKU AND
               LA.Lottable01 = @cLottable01 AND
               LA.Lottable02 = @cLottable02
        ORDER BY
               LA.Lottable05
              ,LOT.LOT

        IF @cLottable03<>'' AND @cLottable03 IS NOT NULL
        BEGIN
            -- SET ROWCOUNT 0

            SELECT @nNoOfComponents = COUNT(DISTINCT ComponentSKU)
                  ,@nComponentQty = SUM(Qty)
            FROM   BillOfMaterial WITH (NOLOCK)
            WHERE  StorerKey = @cStorerKey AND
                   SKU = @cLottable03

            IF (
                   SELECT COUNT(DISTINCT SKU)
                   FROM   @t_AssignPrePack -- Vicky01
                   WHERE  SKU IN (SELECT ComponentSKU
                                  FROM   BillOfMaterial WITH (NOLOCK)
                                  WHERE  StorerKey = @cStorerKey AND
                                         SKU = @cLottable03) AND
                          Lottable01 = @cLottable01 AND
                          Lottable02 = @cLottable02 AND
                          Style = @cStyle
                   HAVING FLOOR(SUM(OpenQty)/@nComponentQty)>1
               ) = @nNoOfComponents
            BEGIN
                UPDATE @t_AssignPrePack
                SET    PrePackIndicator = '*PK'+CAST(@nPackSeq AS NVARCHAR(10))
                      ,Lottable03 = @cLottable03
                FROM   @t_AssignPrePack A
                       JOIN (
                                SELECT OrderKey
                                      ,OrderLineNumber
                                FROM   @t_AssignPrePack
                                WHERE  SKU IN (SELECT ComponentSKU
                                               FROM   BillOfMaterial WITH (NOLOCK)
                                               WHERE  StorerKey = @cStorerKey AND
                                                      SKU = @cLottable03) AND
                                       Lottable01 = @cLottable01 AND
                                       Lottable02 = @cLottable02 AND
                                       Style = @cStyle
                            ) B
                            ON  A.OrderKey = B.OrderKey AND
                                A.OrderLineNumber = B.OrderLineNumber

               SET @nPackSeq = @nPackSeq + 1
            END
            ELSE
            BEGIN
                UPDATE @t_AssignPrePack
                SET    PrePackIndicator = 'X'
                WHERE  OrderKey = @cOrderKey AND
                       OrderLineNumber = @cOrderLineNumber
            END

            IF @b_debug = 1
            BEGIN
                SELECT @nNoOfComponents '@nNoOfComponents'
                      ,@nComponentQty '@nComponentQty'
                      ,@cLottable03 '@cLottable03'
                      ,@cStyle '@cStyle'
                      ,@cSKU '@cSKU'
            END
        END
        ELSE
        BEGIN
            -- SET ROWCOUNT 0

            UPDATE @t_AssignPrePack
            SET    PrePackIndicator = 'X'
            WHERE  OrderKey = @cOrderKey AND
                   OrderLineNumber = @cOrderLineNumber
        END
        -- BREAK
    END
    -- SET ROWCOUNT 0

    IF @b_debug = 1
    BEGIN
        SELECT * FROM @t_AssignPrePack
    END

    UPDATE ORDERDETAIL
    SET    UserDefine03 = PrePackIndicator
          ,TrafficCop = NULL
    FROM   ORDERDETAIL A
           JOIN @t_AssignPrePack B
                ON  A.OrderKey = B.OrderKey AND
                    A.OrderLineNumber = B.OrderLineNumber
    WHERE  PrePackIndicator<>'X'

    ----------------------------------------------------------------------------------------------------------------

    DECLARE @t_ParentSKU     TABLE (SKU NVARCHAR(20) ,NoOfComp INT)

    -- Step 1
    -- Lookup the Pre-Pack SKU code base on the UserDefine03 (Pre-pack indicator)
    -- UserDefine03 was the grouping of number of Components in the BOM
    -- Base on the Components, lookup for BOM SKU and update the Lottable03 as BOM SKU code
    DECLARE @t_PrePackOrder  TABLE
            (
                Facility         NVARCHAR(5)
               ,OrderKey         NVARCHAR(10)
               ,StorerKey        NVARCHAR(15)
               ,Style            NVARCHAR(20)
               ,PrePackIndicator NVARCHAR(18)
               ,NoOfComponents   INT
               ,ParentSKU        NVARCHAR(20)
               ,Lottable01       NVARCHAR(18)
               ,Lottable02       NVARCHAR(18)
               ,Lottable04       DATETIME
               ,BOM_Qty          INT
               ,QtyAllocated     INT
            )

    -- Insert OutStanding Order Lines in to PrePackOrder temp table
    -- Group by Style and Pre Pack Indicator
    DELETE @t_PrePackOrder

    INSERT INTO @t_PrePackOrder
    SELECT ORDERS.Facility
          ,ORDERS.OrderKey
          ,ORDERDETAIL.StorerKey
          ,SKU.Style
          ,ISNULL(ORDERDETAIL.UserDefine03 ,'') AS [PrePackIndicator]
          ,COUNT(ORDERDETAIL.SKU) AS NoOfComponents
          ,'' AS ParentSKU
          ,Lottable01
          ,Lottable02
          ,Lottable04
          ,0 AS BOM_Qty
          ,0 AS QtyAllocated
    FROM   ORDERS(NOLOCK)
           JOIN ORDERDETAIL(NOLOCK)
                ON  (ORDERDETAIL.OrderKey=ORDERS.OrderKey)
           JOIN LoadPlanDetail(NOLOCK)
                ON  (LoadPlanDetail.OrderKey=ORDERS.OrderKey)
           JOIN SKU(NOLOCK)
                ON  (
                        SKU.StorerKey=ORDERDETAIL.StorerKey AND
                        SKU.SKU=ORDERDETAIL.SKU
                    )
    WHERE  ORDERS.Status<'9' AND
           LoadPlanDetail.LoadKey = @c_oskey AND
           (
               ORDERDETAIL.UserDefine03 IS NOT NULL AND
               ORDERDETAIL.UserDefine03<>''
           )
    GROUP BY
           ORDERS.Facility
          ,ORDERS.OrderKey
          ,ORDERDETAIL.StorerKey
          ,SKU.Style
          ,ISNULL(ORDERDETAIL.UserDefine03 ,'')
          ,Lottable01
          ,Lottable02
          ,Lottable04
    HAVING SUM(
               ORDERDETAIL.OpenQty- ORDERDETAIL.QtyAllocated- ORDERDETAIL.QtyPicked
           )>0

    IF @b_debug = 1
    BEGIN
      PRINT 'Temp Table @t_PrePackOrder'
      SELECT OrderKey
            ,StorerKey
            ,Style
            ,PrePackIndicator
            ,NoOfComponents
            ,Lottable01
            ,Lottable02
            ,Lottable04
      FROM   @t_PrePackOrder
      ORDER BY
             OrderKey
            ,Style
            ,PrePackIndicator
    END

    DECLARE C_PrePackOrder CURSOR LOCAL FAST_FORWARD READ_ONLY
    FOR
        SELECT OrderKey
              ,StorerKey
              ,Style
              ,PrePackIndicator
              ,NoOfComponents
              ,Lottable01
              ,Lottable02
              ,Lottable04
        FROM   @t_PrePackOrder
        ORDER BY
               OrderKey
              ,Style
              ,PrePackIndicator

    OPEN C_PrePackOrder

    FETCH NEXT FROM C_PrePackOrder INTO @cOrderKey, @cStorerKey, @cStyle, @cPrePackIndicator, @nNoOfComponents, @cLottable01,
                                        @cLottable02, @dLottable04

    WHILE @@FETCH_STATUS<>-1
    BEGIN
        DELETE
        FROM   @t_ParentSKU

        -- Retrieve a list of Parent SKU from BOM where have same style and no of component
        INSERT INTO @t_ParentSKU
        SELECT B.SKU
              ,COUNT(ComponentSku)
        FROM   BillOfMaterial B WITH (NOLOCK)
               JOIN SKU S WITH (NOLOCK)
                    ON  B.StorerKey = S.StorerKey AND
                        B.ComponentSku = S.SKU
        WHERE  S.StorerKey = @cStorerKey AND
               S.Style = @cStyle
        GROUP BY
               B.SKU
        HAVING COUNT(ComponentSku) = @nNoOfComponents

        IF @@ROWCOUNT=0
        BEGIN
            -- If none on the records found, then reject this Style and Pre-Pack
            UPDATE @t_PrePackOrder
            SET    ParentSKU = 'BAD BOM'
                  ,BOM_Qty = 0
            WHERE  ORDERKEY = @cOrderKey AND
                   Style = @cStyle AND
                   PrePackIndicator = @cPrePackIndicator AND
                   Lottable01 = @cLottable01 AND
                   Lottable02 = @cLottable02 AND
                   Lottable04 = @dLottable04

            GOTO GetNextPrePackOrder
        END

        SELECT @nParentSKUFound = COUNT(*)
        FROM   @t_ParentSKU

        SET @nRatio = 0

        -- If Number of Style + No of Components matched, then compare SKU by SKU
        -- Declare a cursor loop for parent SKU found.
        DECLARE C_ParentSKU CURSOR LOCAL FAST_FORWARD READ_ONLY
        FOR
            SELECT SKU
            FROM   @t_ParentSKU

        OPEN C_ParentSKU

        FETCH NEXT FROM C_ParentSKU INTO @cParentSKU

        WHILE @@FETCH_STATUS<>-1
        BEGIN
            --          SET @bParentSKUFound = 0
            --          SET @nBOMQty = 0

            IF NOT EXISTS(
                   SELECT 1
                   FROM   BillOfMaterial WITH (NOLOCK)
                   WHERE  StorerKey = @cStorerkey AND
                          SKU = @cParentSKU AND
                          ComponentSKU IN (SELECT ORDERDETAIL.SKU
                                           FROM   ORDERDETAIL WITH (NOLOCK)
                                                  JOIN SKU WITH (NOLOCK)
                                                       ON  (
                                                               SKU.StorerKey=
                                                               ORDERDETAIL.StorerKey AND
                                                               SKU.SKU=
                                                               ORDERDETAIL.SKU
                                                           )
                                           WHERE  OrderKey = @cOrderKey AND
                                                  SKU.Style = @cStyle AND
                                                  ORDERDETAIL.UserDefine03 = @cPrePackIndicator AND
                                                  ORDERDETAIL.Lottable01 = @cLottable01 AND
                                                  ORDERDETAIL.Lottable02 = @cLottable02 AND
                                                  ORDERDETAIL.Lottable04 = @dLottable04)
               )
            BEGIN
                GOTO GetNextParentSKU
            END

            IF (@cLottable01 IS NOT NULL AND @cLottable01<>'') OR
               (@cLottable02 IS NOT NULL AND @cLottable02<>'')
            BEGIN
                IF NOT EXISTS(
                       SELECT 1
                       FROM   LOT L WITH (NOLOCK)
                              JOIN LOTATTRIBUTE LA WITH (NOLOCK)
                                   ON  LA.LOT = L.LOT
                       WHERE  LA.StorerKey = @cStorerKey AND
                              LA.Lottable01 = CASE
                                                   WHEN @cLottable01='' THEN LA.Lottable01
                                                   ELSE @cLottable01
                                              END AND
                              LA.Lottable02 = CASE
                                                   WHEN @cLottable02='' THEN LA.Lottable02
                                                   ELSE @cLottable02
                                              END AND
                              L.Qty- L.QtyAllocated- L.QtyPicked- L.QtyPreAllocated
                             >0
                   )
                BEGIN
                    GOTO GetNextParentSKU
                END
            END

            SET @bParentSKUFound = 1
            SET @nBOMQty = 0

            DECLARE C_ComponentSKU  CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR
                SELECT ORDERDETAIL.SKU
                      ,ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated -- SOS# 167072
                      - ORDERDETAIL.QtyPicked --SOS# 194063
                FROM   ORDERDETAIL WITH (NOLOCK)
                       JOIN SKU WITH (NOLOCK)
                            ON  (
                                    SKU.StorerKey=ORDERDETAIL.StorerKey AND
                                    SKU.SKU=ORDERDETAIL.SKU
                                )
                WHERE  OrderKey = @cOrderKey AND
                       SKU.Style = @cStyle AND
                       ORDERDETAIL.UserDefine03 = @cPrePackIndicator AND
                       ORDERDETAIL.Lottable01 = @cLottable01 AND
                       ORDERDETAIL.Lottable02 = @cLottable02 AND
                       ORDERDETAIL.Lottable04 = @dLottable04

            OPEN C_ComponentSKU

            FETCH NEXT FROM C_ComponentSKU INTO @cComponentSKU, @nOpenQty

            WHILE @@Fetch_Status<>-1
            BEGIN
                --SET ROWCOUNT 1

                SET @nComponentQty = 0

                SELECT TOP 1 
                       @nComponentQty = Qty
                FROM   BillOfMaterial WITH (NOLOCK)
                WHERE  StorerKey = @cStorerkey 
                AND    SKU = @cParentSKU 
                AND    ComponentSKU = @cComponentSKU

                IF @nOpenQty<@nComponentQty -- 30-Oct-2007 Shong
                BEGIN
                    CLOSE C_ComponentSKU
                    DEALLOCATE C_ComponentSKU
                    GOTO GetNextParentSKU
                END

                IF @nRatio=0
                    SET @nRatio = @nOpenQty/@nComponentQty

                -- Select @cParentSKU '@cParentSKU', @cComponentSKU '@cComponentSKU', @nComponentQty '@nComponentQty', @nRatio '@nRatio',
                --       @nOpenQty '@nOpenQty', @nParentSKUFound '@nParentSKUFound'

                IF @nRatio<>(@nOpenQty/@nComponentQty) AND
                   @nParentSKUFound>1
                BEGIN
                    CLOSE C_ComponentSKU
                    DEALLOCATE C_ComponentSKU
                    GOTO GetNextParentSKU
                END

                IF @nComponentQty=0 OR
                   @nComponentQty IS NULL
                BEGIN
                    -- SET ROWCOUNT 0
                    -- If OrderDetail Component SKU not match to the
                    UPDATE @t_PrePackOrder
                    SET    ParentSKU = 'BAD BOM'
                          ,BOM_Qty = 0
                    WHERE  ORDERKEY = @cOrderKey AND
                           Style = @cStyle AND
                           PrePackIndicator = @cPrePackIndicator AND
                           Lottable01 = @cLottable01 AND
                           Lottable02 = @cLottable02 AND
                           Lottable04 = @dLottable04

                    SET @bParentSKUFound = 0

                    BREAK
                END
                ELSE
                BEGIN
                    -- SET ROWCOUNT 0
                    -- IF @nOpenQty % @nComponentQty > 0
                    -- BEGIN
                    --    UPDATE @t_PrePackOrder
                    --       SET ParentSKU = 'BAD RATIO', BOM_Qty = 0
                    --    WHERE ORDERKEY = @cOrderKey
                    --    AND   Style = @cStyle
                    --    AND   PrePackIndicator = @cPrePackIndicator
                    --    AND   Lottable01 = @cLottable01
                    --    AND   Lottable02 = @cLottable02
                    --    AND   Lottable04 = @dLottable04
                    --
                    --    SET @bParentSKUFound = 0
                    --
                    --    CLOSE C_ParentSKU
                    --    DEALLOCATE C_ParentSKU
                    --    CLOSE C_ComponentSKU
                    --    DEALLOCATE C_ComponentSKU
                    --    GOTO GetNextPrePackOrder
                    --
                    -- END

                    IF @nBOMQty=0
                    BEGIN
                        SET @nBOMQty = FLOOR(@nOpenQty/@nComponentQty)
                    END
                    ELSE
                    IF @nBOMQty>FLOOR(@nOpenQty/@nComponentQty)
                    BEGIN
                        SET @nBOMQty = FLOOR(@nOpenQty/@nComponentQty)
                    END
                END

                SET ROWCOUNT 0
                -- Get next Component SKU
                FETCH NEXT FROM C_ComponentSKU INTO @cComponentSKU, @nOpenQty
            END -- While Loop C_ComponentSKU
            CLOSE C_ComponentSKU
            DEALLOCATE C_ComponentSKU

            IF @bParentSKUFound = 1
            BEGIN
                UPDATE @t_PrePackOrder
                SET    ParentSKU = @cParentSKU
                      ,BOM_Qty = @nBOMQty
                WHERE  ORDERKEY = @cOrderKey AND
                       Style = @cStyle AND
                       PrePackIndicator = @cPrePackIndicator

                -- Making Use of Lottable03 = Parent SKU and QtyToProcess = Parent SKU Quantity
                UPDATE ORDERDETAIL WITH (ROWLOCK)
                SET    Lottable03 = @cParentSKU
                      ,QtyToProcess = @nBOMQty
                      ,TrafficCop = NULL
                FROM   ORDERDETAIL
                       JOIN SKU WITH (NOLOCK)
                            ON  (
                                    SKU.StorerKey=ORDERDETAIL.StorerKey AND
                                    SKU.SKU=ORDERDETAIL.SKU
                                )
                WHERE OrderKey = @cOrderKey AND
                       SKU.Style = @cStyle AND
                       ORDERDETAIL.UserDefine03 = @cPrePackIndicator

                CLOSE C_ParentSKU
                DEALLOCATE C_ParentSKU
                GOTO GetNextPrePackOrder
            END

               GetNextParentSKU:

            SET @nRatio = 0

            FETCH NEXT FROM C_ParentSKU INTO @cParentSKU
        END -- Cursor Loop for C_ParentSKU
        CLOSE C_ParentSKU
        DEALLOCATE C_ParentSKU

        IF @bParentSKUFound=0
        BEGIN
            -- SET ROWCOUNT 0
            -- If OrderDetail Component SKU not match to the
            UPDATE @t_PrePackOrder
            SET    ParentSKU = 'BAD BOM'
                  ,BOM_Qty = 0
            WHERE  ORDERKEY = @cOrderKey AND
                   Style = @cStyle AND
                   PrePackIndicator = @cPrePackIndicator AND
                   Lottable01 = @cLottable01 AND
                   Lottable02 = @cLottable02 AND
                   Lottable04 = @dLottable04

            SET @bParentSKUFound = 0

            BREAK
        END

           GetNextPrePackOrder:

        FETCH NEXT FROM C_PrePackOrder INTO @cOrderKey, @cStorerKey, @cStyle, @cPrePackIndicator, @nNoOfComponents,
                                            @cLottable01, @cLottable02, @dLottable04
    END -- While cursor loop for C_PrePackOrder
    CLOSE C_PrePackOrder
    DEALLOCATE C_PrePackOrder

    IF @b_debug = 1
    BEGIN
        PRINT 'Temp Table result: @t_PrePackOrder'
        SELECT * FROM @t_PrePackOrder
    END

    -- Do not allocate un-match parent sku
    DELETE
    FROM   @t_PrePackOrder
    WHERE  ParentSKU = 'BAD BOM'

    DECLARE @t_QtyAvailable TABLE (
                SeqNo           INT IDENTITY(1 ,1)
               ,StorerKey       NVARCHAR(15)
               ,ParentSKU       NVARCHAR(20)
               ,SKU             NVARCHAR(20)
               ,LOT             NVARCHAR(10)
               ,LOC             NVARCHAR(10)
               ,ID              NVARCHAR(18)
               ,Qty             INT
               ,SortOrder       INT
               ,QtyAllocated    INT
               ,BOMQty          INT
               ,LogicalLocation NVARCHAR(10)
            )

    IF @b_debug = 1
    BEGIN
        SELECT Facility
              ,StorerKey
              ,ParentSKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,Style
              ,SUM(BOM_Qty)
        FROM   @t_PrePackOrder
        GROUP BY
               Facility
              ,StorerKey
              ,ParentSKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,Style
        HAVING SUM(BOM_Qty)>SUM(QtyAllocated)
    END

    -- Allocate By Orders
    DECLARE C_PrePackAllocationLine  CURSOR LOCAL FAST_FORWARD READ_ONLY
    FOR
        SELECT Facility
              ,StorerKey
              ,ParentSKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,Style
              ,SUM(BOM_Qty)
        FROM   @t_PrePackOrder
        GROUP BY
               Facility
              ,StorerKey
              ,ParentSKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,Style
        HAVING SUM(BOM_Qty) > SUM(QtyAllocated)

    OPEN C_PrePackAllocationLine

    FETCH NEXT FROM C_PrePackAllocationLine INTO @cFacility, @cStorerKey, @cParentSKU, @cLottable01, @cLottable02, @dLottable04,
                                                 @cStyle, @nBOMQty

    WHILE @@Fetch_Status <> -1
    BEGIN
        -- Get Pallet Qty, CaseCnt and Inner Pack
        SELECT @nPalletCnt = PACK.Pallet
              ,@nCaseCnt = PACK.CaseCnt
              ,@nInnerCnt = PACK.InnerPack
        FROM   PACK WITH (NOLOCK)
               JOIN SKU WITH (NOLOCK)
                    ON  PACK.PackKey = SKU.PackKey
        WHERE  SKU.StorerKey = @cStorerKey AND
               SKU.SKU = @cParentSKU

        WHILE @nBOMQty > 0
        BEGIN
            IF @nBOMQty >= @nPalletCnt AND
               @nPalletCnt > 0
            BEGIN
                --SET @nUOMBase = @nPalletCnt
                SET @nUOMBase = 1
                SET @bAllocatePallet = 1
            END
            ELSE
            IF @nBOMQty >= @nCaseCnt AND
               @nCaseCnt > 0
            BEGIN
                --SET @nUOMBase = @nCaseCnt
                SET @nUOMBase = 1
                SET @bAllocatePallet = 0
            END
            ELSE
            IF @nBOMQty >= @nInnerCnt AND
               @nInnerCnt > 0
            BEGIN
                -- SET @nUOMBase = @nInnerCnt
                SET @nUOMBase = 1
                SET @bAllocatePallet = 0
            END
            ELSE
            BEGIN
                SET @nUOMBase = 1
                SET @bAllocatePallet = 0
            END

            DELETE @t_QtyAvailable

            IF @b_debug = 1
            BEGIN
                SELECT @cFacility '@cFacility'
                      ,@cParentSKU '@cParentSKU'
                      ,@nUOMBase '@nUOMBase'
                      ,@nPalletCnt '@nPalletCnt'
                      ,@nCaseCnt '@nCaseCnt'
                      ,@nInnerCnt '@nInnerCnt'
                      ,@nBOMQty '@nBOMQty'
            END

            INSERT INTO @t_QtyAvailable
              (
                StorerKey, ParentSKU, SKU, LOT, LOC, ID, Qty, SortOrder,
                QtyAllocated, BOMQty, LogicalLocation
              )
            SELECT LOTxLOCxID.StorerKey
                  ,BOM.SKU
                  ,LOTxLOCxID.SKU
                  ,LOT.LOT
                  ,LOTxLOCxID.LOC
                  ,LOTxLOCxID.ID
                  ,FLOOR(
                       (
                           LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED
                       )
                   )-(
                       FLOOR(
                           LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED
                          /BOM.Qty
                       ) % @nUOMBase
                   ) AS QtyAvailable
                  ,CASE
                        WHEN @bAllocatePallet=1 AND LOC.LOCLevel>1 THEN 1
                        WHEN @bAllocatePallet=0 AND LOC.LOCLevel=1 THEN 1
                        WHEN @bAllocatePallet=0 AND LOC.LOCLevel>1 THEN 2
                        ELSE 10
                   END AS SortOrder
                  ,QtyAllocated = 0
                  ,(
                       FLOOR(
                           (
                               LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED-
                               LOTxLOCxID.QTYPICKED
                           )-
                           FLOOR(
                               (
                                   LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED-
                                   LOTxLOCxID.QTYPICKED
                               )/BOM.Qty
                           ) % @nUOMBase
                       )
                   )/BOM.Qty AS BomQty
                  ,Loc.LogicalLocation
            FROM   LOT WITH (NOLOCK)
                   JOIN LOTATTRIBUTE WITH (NOLOCK)
                        ON  (LOT.LOT=LOTATTRIBUTE.LOT)
                   JOIN LOTxLOCxID WITH (NOLOCK)
                        ON  (LOTxLOCxID.LOT=LOT.LOT)
                   JOIN LOC WITH (NOLOCK)
                        ON  (
                                LOTxLOCxID.LOC=LOC.LOC AND
                                LOC.STATUS='OK' AND
                                LOC.LocationFlag NOT IN ('HOLD' ,'DAMAGE')
                            )
                   JOIN ID WITH (NOLOCK)
                        ON  (LOTxLOCxID.ID=ID.ID AND ID.STATUS='OK')
                   JOIN BillOfMaterial BOM(NOLOCK)
                        ON  (
                                BOM.StorerKey=LOTxLOCxID.StorerKey AND
                                BOM.ComponentSKU=LOTxLOCxID.SKU AND
                                BOM.Qty>0
                            )
            WHERE  LOTxLOCxID.STORERKEY = @cStorerkey AND
                   LOT.STATUS = 'OK' AND
                   LOC.FACILITY = @cFacility AND
                   BOM.StorerKey = @cStorerKey AND
                   BOM.SKU = @cParentSKU AND
                   LOTAttribute.Lottable03 = @cParentSKU AND
                   FLOOR(
                       LOTxLOCxID.QTY- LOTxLOCxID.QTYALLOCATED- LOTxLOCxID.QTYPICKED
                      /BOM.Qty
                   )>= @nUOMBase AND
                   Lottable01 = CASE
                                     WHEN @cLottable01<>'' THEN @cLottable01
                                     ELSE Lottable01
                                END AND
                   Lottable02 = CASE
                                     WHEN @cLottable02<>'' THEN @cLottable02
                                     ELSE Lottable02
                                END AND
                   LOC.LocationCategory<>'LOOSE' -- Modified on 08-Oct-2007
            ORDER BY
                   SortOrder
                  ,Loc.LogicalLocation
                  ,Loc.Loc
                  ,LOTxLOCxID.ID -- Modified on 08-Oct-2007

            IF @dLottable04 IS NOT NULL AND
               @dLottable04<>'19000101'
            BEGIN
                DELETE @t_QtyAvailable
                FROM   @t_QtyAvailable t
                       JOIN LOTATTRIBUTE WITH (NOLOCK)
                            ON  (t.LOT=LOTATTRIBUTE.LOT)
                WHERE  LOTATTRIBUTE.Lottable04<>@dLottable04
            END

            IF @b_debug = 1
            BEGIN
                PRINT 'Before - Temp Table result: @t_QtyAvailable'
                SELECT * FROM   @t_QtyAvailable
            END

            -- Delete the line with less Components
            DECLARE @nTotRatio INT

            SELECT @nNoOfComponents = COUNT(DISTINCT ComponentSku)
                  ,@nTotRatio = SUM(Qty)
            FROM   BillOfMaterial WITH (NOLOCK)
            WHERE  StorerKey = @cStorerKey AND
                   BillOfMaterial.SKU = @cParentSKU


            IF @b_debug = 1
            BEGIN
                PRINT 'Delete Row without full componenets....'
                SELECT StorerKey
                      ,ParentSKU
                      ,LOC
                      ,ID
                      ,SUM(Qty) AS Qty
                      ,COUNT(DISTINCT SKU) AS Components
                      ,SUM(Qty) % @nTotRatio AS RemainingQty
                      ,@nNoOfComponents '@nNoOfComponents'
                      ,@nTotRatio '@nTotRatio'
                FROM   @t_QtyAvailable
                GROUP BY
                       StorerKey
                      ,ParentSKU
                      ,LOC
                      ,ID
            END

            DELETE @t_QtyAvailable
            FROM   @t_QtyAvailable t
                   JOIN (
                            SELECT StorerKey
                                  ,ParentSKU
                                  ,LOC
                                  ,ID
                                  ,SUM(Qty) AS Qty
                                  ,COUNT(DISTINCT SKU) AS Components
                            FROM   @t_QtyAvailable
                            GROUP BY
                                   StorerKey
                                  ,ParentSKU
                                  ,LOC
                                  ,ID
                            HAVING COUNT(DISTINCT SKU)<>@nNoOfComponents
                                   --OR     SUM(Qty) % @nTotRatio <> 0
                                    OR
                            FLOOR(SUM(Qty)/@nTotRatio)=0
                        ) AS ta
                        ON  ta.StorerKey = t.StorerKey AND
                            ta.ParentSKU = t.ParentSKU AND
                            ta.LOC = t.LOC AND
                            ta.ID = t.ID

            -- No Stock
            IF (
                   SELECT COUNT(*)
                   FROM   @t_QtyAvailable
               ) = 0
            BEGIN
                SET @nBOMQty = 0
                BREAK
            END

            --
            -- SOS 110959 Start
            --         UPDATE @t_QtyAvailable
            --            SET BOMQty = BOMGroup.BOMQty
            --         FROM @t_QtyAvailable A
            --         JOIN (SELECT ParentSKU, LOC, ID, COUNT(DISTINCT SKU) NoOfComponents,
            --               Min(BOMQty) AS BOMQty
            --               FROM @t_QtyAvailable
            --               GROUP BY ParentSKU, LOC, ID) AS BOMGroup ON BOMGroup.ParentSKU = A.ParentSKU
            --                  AND BOMGroup.LOC = A.LOC AND BOMGroup.ID = A.ID
            UPDATE A
            SET    BOMQty = BOMGroup.BOMQty
            FROM   @t_QtyAvailable A
                   JOIN LOTATTRIBUTE LA WITH (NOLOCK)
                        ON  LA.LOT = A.LOT
                   JOIN (
                            SELECT tQA.ParentSKU
                                  ,tQA.LOC
                                  ,tQA.ID
                                  ,COUNT(DISTINCT tQA.SKU) NoOfComponents
                                  ,MIN(BOMQty) AS BOMQty
                                  ,LA.Lottable05
                            FROM   @t_QtyAvailable tQA
                                   JOIN LOTATTRIBUTE LA WITH (NOLOCK)
                                        ON  LA.LOT = tQA.LOT
                            GROUP BY
                                   ParentSKU
                                  ,LOC
                                  ,ID
                                  ,LA.Lottable05
                        ) AS BOMGroup
                        ON  BOMGroup.ParentSKU = A.ParentSKU AND
                            BOMGroup.LOC = A.LOC AND
                            BOMGroup.ID = A.ID AND
                            BOMGroup.Lottable05 = LA.Lottable05
            -- SOS 110959 End

            -- BREAK

            IF @b_debug = 1
            BEGIN
                PRINT 'Temp Table result: @t_QtyAvailable'
                SELECT * FROM   @t_QtyAvailable
                ORDER BY
                       SortOrder
                      ,LogicalLocation
                      ,Loc
                      ,ParentSKU
                      ,ID
               -- select ParentSKU, LOC, ID, COUNT(DISTINCT SKU) NoOfComponents,
               --        Min(BOMQty) AS BOMQty
               -- from @t_QtyAvailable
               -- group by ParentSKU, LOC, ID
            END

            SET @nBOMQtyToTake = 0
            SET @cPrevPrePackIndicator = ''
            SET @cPrevOrderKey = ''

            -----------------
            IF (
                   SELECT COUNT(*)
                   FROM   OrderDetail OD WITH (NOLOCK)
                          JOIN @t_PrePackOrder PPO
                               ON  OD.OrderKey = PPO.OrderKey AND
                                   OD.Lottable03 = PPO.ParentSKU AND
                                   OD.UserDefine03 = PPO.PrePackIndicator
                   WHERE  PPO.Lottable02 = @cLottable02 AND
                          PPO.Lottable01 = @cLottable01 AND
                          PPO.Lottable04 = @dLottable04 AND
                          PPO.ParentSKU = @cParentSKU AND
                          PPO.StorerKey = @cStorerKey AND
                          (OD.OpenQty- OD.QtyAllocated - OD.QtyPicked) > 0 -- SOS# 194063
               ) = 0
            BEGIN
                BREAK
            END
            -----------------

            DECLARE C_OrderLine  CURSOR LOCAL FAST_FORWARD READ_ONLY
            FOR
                SELECT OD.OrderKey
                      ,OD.OrderLineNumber
                      ,OD.SKU
                      ,OD.OpenQty- OD.QtyAllocated - OD.QtyPicked -- SOS# 194063
                      ,PPO.PrePackIndicator
                      ,OD.QtyToProcess
                FROM   OrderDetail OD WITH (NOLOCK)
                       JOIN @t_PrePackOrder PPO
                            ON  OD.OrderKey = PPO.OrderKey AND
                                OD.Lottable03 = PPO.ParentSKU AND
                                OD.UserDefine03 = PPO.PrePackIndicator
                WHERE  PPO.Lottable02 = @cLottable02 AND
                       PPO.Lottable01 = @cLottable01 AND
                       PPO.Lottable04 = @dLottable04 AND
                       PPO.ParentSKU = @cParentSKU AND
                       PPO.StorerKey = @cStorerKey AND
                       (OD.OpenQty- OD.QtyAllocated - OD.QtyPicked) > 0 -- SOS# 194063
                ORDER BY
                       OD.OrderKey
                      ,PPO.PrePackIndicator
                      ,OD.OrderLineNumber

            OPEN C_OrderLine

            FETCH NEXT FROM C_OrderLine INTO @cOrderKey, @cOrderLineNumber, @cSKU,
                                             @nOpenQty, @cPrePackIndicator, @nQtyToProcess

            WHILE @@FETCH_STATUS <> -1
            BEGIN
                IF @cPrevPrePackIndicator=''
                    SET @cPrevPrePackIndicator = @cPrePackIndicator

                IF @cPrevOrderKey=''
                    SET @cPrevOrderKey = @cOrderKey

                IF @cPrevPrePackIndicator <> @cPrePackIndicator OR @cPrevOrderKey <> @cOrderKey
                BEGIN
                    SET @cPrevPrePackIndicator = @cPrePackIndicator
                    SET @cPrevOrderKey = @cOrderKey
                    SET @nBOMQty = @nBOMQty - @nBOMQtyToTake
                END

                SELECT @nBOMQtyToTake = FLOOR(@nOpenQty/BOM.Qty)
                      ,@nComponentQty = BOM.Qty
                FROM   BillOfMaterial BOM WITH (NOLOCK)
                WHERE  StorerKey = @cStorerKey AND
                       SKU = @cParentSKU AND
                       ComponentSKU = @cSKU

                IF @nBOMQtyToTake > @nQtyToProcess
                    SET @nBOMQtyToTake = @nQtyToProcess

                IF @nBOMQtyToTake > @nBOMQty
                    SET @nBOMQtyToTake = @nBOMQty

                SET @nQtyToFullFill = (@nBOMQtyToTake*@nComponentQty)

                WHILE 1=1 AND @nQtyToFullFill > 0
                BEGIN
                    IF @b_debug = 1
                    BEGIN
                        SELECT @nBOMQtyToTake '@nBOMQtyToTake'
                              ,@nBOMQty '@nBOMQty'
                              ,@cParentSKU '@cParentSKU'
                              ,@cSKU 'ComponentSKU'
                              ,@nOpenQty '@nOpenQty'
                    END

                    --SET ROWCOUNT 1

                    SELECT TOP 1 
                           @cLOT = LOT
                          ,@cLOC = LOC
                          ,@cID = ID
                          ,@nQtyToTake = (BOMQty*@nComponentQty)- QtyAllocated
                    FROM   @t_QtyAvailable
                    WHERE  StorerKey = @cStorerKey 
                    AND    SKU = @cSKU 
                    AND    ParentSKU = @cParentSKU
                    AND    (BOMQty*@nComponentQty)- QtyAllocated>0                                                       
                    ORDER BY SeqNo

                    IF @@ROWCOUNT=0
                    BEGIN
                        --SET ROWCOUNT 0
                        BREAK
                    END

                    --SET ROWCOUNT 0

                    IF @nQtyToTake > @nQtyToFullFill
                        SET @nQtyToTake = @nQtyToFullFill

                    SELECT @cPackKey = PackKey
                    FROM   SKU WITH (NOLOCK)
                    WHERE  StorerKey = @cStorerKey 
                    AND    SKU = @cSKU

                    SELECT @b_Success = 0
                    EXECUTE nspg_getkey
                             'PickDetailKey'
                             , 10
                             , @cPickDetailKey OUTPUT
                             , @b_Success      OUTPUT
                             , @n_err          OUTPUT
                             , @c_errmsg       OUTPUT


                    IF @b_debug = 1
                    BEGIN
                        PRINT 'Insert Into PickDetail...(PREPACK)'
                        SELECT @cPickDetailKey '@cPickDetailKey'
                              ,@cOrderKey '@cOrderKey'
                              ,@cOrderLineNumber '@cOrderLineNumber'
                              ,@cLOT '@cLOT'
                              ,@cLOC 'LOC'
                              ,@cID 'ID'
                              ,@cSKU 'SKU'
                              ,@cStorerKey '@cStorerKey'
                              ,@cParentSKU '@cParentSKU'
                              ,@nBOMQtyToTake '@nBOMQtyToTake'
                              ,@nQtyToTake '@nQtyToTake'
                              ,@cPackKey '@cPackKey'
                              ,@cParentSKU '@cParentSKU'
                    END

                    INSERT PICKDETAIL
                      (
                        PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,
                        Lot, Storerkey, Sku, Qty, Loc, Id, UOMQty, UOM, CaseID,
                        PackKey, CartonGroup, DoReplenish, replenishzone,
                        docartonize, Trafficcop, PickMethod, AltSku
                      )
                    VALUES
                      (
                        @cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cLOT,
                        @cStorerKey, @cSKU, @nQtyToTake, @cLOC, @cID, @nBOMQtyToTake,
                        '6', '', @cPackKey, 'PREPACK', 'N', '', 'N', 'U', '8', @cParentSKU
                      )

                    UPDATE @t_QtyAvailable
                    SET    QtyAllocated = QtyAllocated+@nQtyToTake
                    WHERE  LOT = @cLOT AND
                           LOC = @cLOC AND
                           ID = @cID

                    SET @nQtyToFullFill = @nQtyToFullFill- @nQtyToTake

                    -- IF @cPrevPrePackIndicator <> @cPrePackIndicator OR
                    --    @cPrevOrderKey <> @cOrderKey
                    -- BEGIN
                    --    SET @cPrevPrePackIndicator = @cPrePackIndicator
                    --    SET @cPrevOrderKey = @cOrderKey
                    --    SET @nBOMQty = @nBOMQty - @nBOMQtyToTake
                    -- END

                    IF @b_debug = 1
                    BEGIN
                        SELECT @cPrevPrePackIndicator '@cPrevPrePackIndicator'
                              ,@cPrePackIndicator '@cPrePackIndicator'
                              ,@cPrevOrderKey '@cPrevOrderKey'
                              ,@cOrderKey '@cOrderKey'
                              ,@nBOMQty '@nBOMQty'
                    END

                    IF @nQtyToFullFill = 0
                    BEGIN
                       BREAK
                    END

                    IF @nBOMQty = 0
                    BEGIN
                       BREAK
                    END
                END

                FETCH NEXT FROM C_OrderLine INTO @cOrderKey, @cOrderLineNumber,
                @cSKU, @nOpenQty, @cPrePackIndicator, @nQtyToProcess
            END -- While loop for C_OrderLine
            CLOSE C_OrderLine
            DEALLOCATE C_OrderLine

            SET @nBOMQty = @nBOMQty- @nBOMQtyToTake
        END -- While BOMQty > 0
            -- Allocate from Orders

        FETCH NEXT FROM C_PrePackAllocationLine INTO @cFacility, @cStorerKey, @cParentSKU, @cLottable01, @cLottable02, @dLottable04,
                                                     @cStyle, @nBOMQty
    END
    CLOSE C_PrePackAllocationLine
    DEALLOCATE C_PrePackAllocationLine

    -- TITAN Project
    -- BOM (packing) Allocation
    IF @b_debug = 1
    BEGIN
       PRINT 'Start BOM Packing Allocation'
    END

    DECLARE @nBOMCaseCnt  int
           ,@cBOMSKU      NVARCHAR(20)

    DECLARE C_BOMPackingQtyOrdLine  CURSOR LOCAL FAST_FORWARD READ_ONLY
    FOR
        SELECT ORDERS.Facility
              ,ORDERS.OrderKey
              ,ORDERS.StorerKey
              ,ORDERDETAIL.OrderLineNumber
              ,ORDERDETAIL.SKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked AS
               Qty
        FROM   ORDERS(NOLOCK)
               JOIN ORDERDETAIL(NOLOCK)
                    ON  (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
               JOIN LoadPlanDetail(NOLOCK)
                 ON  (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
               JOIN SKU(NOLOCK)
                    ON  (
                            SKU.StorerKey = ORDERDETAIL.StorerKey AND
                            SKU.SKU = ORDERDETAIL.SKU
                        )
               JOIN StorerConfig SCfg WITH (NOLOCK)
                    ON (
                            SCfg.StorerKey = ORDERS.StorerKey AND
                            SCfg.ConfigKey = 'PREPACKBYBOM' AND
                            SCfg.sValue    = '1'
                       )
               JOIN StorerConfig SCfg2 WITH (NOLOCK)
                    ON (
                            SCfg2.StorerKey = ORDERS.StorerKey AND
                            SCfg2.ConfigKey = 'PREPACKCONSOALLOCATION' AND
                            SCfg2.sValue    = '1'
                       )
        WHERE  ORDERS.Status < '9' AND
               LoadPlanDetail.LoadKey = @c_oskey AND
               (
                   ORDERDETAIL.OpenQty - ORDERDETAIL.QtyAllocated - ORDERDETAIL.QtyPicked
               ) > 0
        ORDER BY
               ORDERDETAIL.UserDefine03
              ,ORDERS.OrderKey
              ,ORDERDETAIL.OrderLineNumber

    OPEN C_BOMPackingQtyOrdLine

    FETCH NEXT FROM C_BOMPackingQtyOrdLine INTO @cFacility, @cOrderKey, @cStorerKey, @cOrderLineNumber, @cSKU,
                                                @cLottable01, @cLottable02, @dLottable04, @nQty

    WHILE @@FETCH_STATUS <> -1
    BEGIN
        --WHILE @nQty>0
        BEGIN
            DECLARE C_BOM_PACKING_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT (P.CASECNT * BOM.Qty) As BOMCaseCnt,
                   BOM.SKU
            FROM BILLOFMATERIAL BOM (NOLOCK)
            JOIN SKU (NOLOCK) ON BOM.SKU = SKU.SKU AND
                                 BOM.STORERKEY = SKU.STORERKEY
            JOIN PACK P (NOLOCK) ON SKU.PACKKEY = P.PACKKEY
            WHERE BOM.StorerKey = @cStorerKey AND
                  COMPONENTSKU = @cSKU AND
                  (P.CASECNT * BOM.Qty) > 0
            ORDER BY
            CASE WHEN (P.CASECNT * BOM.Qty) > 0 THEN
                 CASE WHEN @nQty % CAST((P.CASECNT * BOM.Qty) AS INT) = 0 THEN 0 ELSE 1 END
                 ELSE 1
            END,
            BOMCaseCnt DESC

            OPEN C_BOM_PACKING_SKU

            FETCH NEXT FROM C_BOM_PACKING_SKU INTO @nBOMCaseCnt, @cBOMSKU

            WHILE @@FETCH_STATUS <> -1 AND @nQty > 0
            BEGIN
               IF (SELECT COUNT(Distinct ComponentSKU) FROM BillOfMaterial WITH (NOLOCK)
                   WHERE StorerKey = @cStorerKey AND SKU = @cBOMSKU) > 1
               BEGIN
                  GOTO GET_NEXT_BOM_PACKING_SKU
               END

               SET @cExecStatements =
                     N'SELECT TOP 1 @cLOT = LOT.LOT,
                                    @cLOC = LOTxLOCxID.LOC,
                                    @cID  = LOTxLOCxID.ID,
                                    @nQtyAvailable = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED
                     FROM LOT WITH (NOLOCK)
                     JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT )
                     JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT)
                     JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC AND LOC.STATUS = ''OK'' AND
                                                LOC.LocationFlag NOT IN (''HOLD'', ''DAMAGE''))
                     JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID AND ID.STATUS = ''OK'')
                     WHERE LOTxLOCxID.STORERKEY = @cStorerkey
                     AND LOTxLOCxID.SKU = @cSKU
                     AND LOT.STATUS = ''OK''
                     AND LOC.FACILITY  = @cFacility
                     AND ( LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED ) >= ' +
                     CONVERT(NVARCHAR(10), @nBOMCaseCnt) +
                     ' AND LOTATTRIBUTE.Lottable03 = N''' +  @cBOMSKU + ''' '

               IF @cLottable01 <> '' AND @cLottable01 IS NOT NULL
               BEGIN
                   SET @cExecStatements = @cExecStatements +
                       ' AND LOTATTRIBUTE.Lottable01 = @cLottable01 '
               END

               IF @cLottable02 <> '' AND @cLottable02 IS NOT NULL
               BEGIN
                   SET @cExecStatements = @cExecStatements +
                       ' AND LOTATTRIBUTE.Lottable02 = @cLottable02 '
               END

               IF @dLottable04 IS NOT NULL AND @dLottable04 <> '19000101'
               BEGIN
                   SET @cExecStatements = @cExecStatements+
                       ' AND LOTATTRIBUTE.Lottable04 = @dLottable04 '
               END

               SET @cExecStatements = @cExecStatements+
                   'ORDER BY CASE WHEN LOC.LocationCategory = ''LOOSE'' THEN 1 ELSE 99 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, Loc.LogicalLocation, Loc.Loc, LOTxLOCxID.ID  '

               SET @cLOT = ''

               IF @b_debug = 2
               BEGIN
                   PRINT 'Searching Qty Available'
                   PRINT @cExecStatements
               END

               EXEC sp_executesql @cExecStatements,
                    N'@cStorerkey NVARCHAR(15), @cSKU NVARCHAR(20), @cFacility NVARCHAR(5), @cLottable01 NVARCHAR(18),
                    @cLottable02 NVARCHAR(18), @dLottable04 datetime, @cLOT NVARCHAR(10) OUTPUT, @cLOC NVARCHAR(10) OUTPUT, @cID NVARCHAR(18) OUTPUT,
                    @nQtyAvailable int OUTPUT '
                   ,@cStorerkey
                   ,@cSKU
                   ,@cFacility
                   ,@cLottable01
                   ,@cLottable02
                   ,@dLottable04
                   ,@cLOT OUTPUT
                   ,@cLOC OUTPUT
                   ,@cID OUTPUT
                   ,@nQtyAvailable OUTPUT

               IF @cLOT IS NOT NULL AND @cLOT <> ''
               BEGIN
                   IF @nQty < @nBOMCaseCnt
                      GOTO GET_NEXT_BOM_PACKING_SKU

                   -- Only pick Full Case Qty
                   SET @nBOMQtyToTake = FLOOR(@nQtyAvailable / @nBOMCaseCnt)

                   SET @nQtyAvailable = @nBOMQtyToTake * @nBOMCaseCnt

                   IF @nQtyAvailable < @nQty
                       SET @nQtyToTake = @nQtyAvailable
                   ELSE
                       SET @nQtyToTake = FLOOR(@nQty / @nBOMCaseCnt) * @nBOMCaseCnt

                   IF @b_debug = 1
                   BEGIN
                       PRINT 'Insert Into PickDetail for BOM Packed Qty...'
                       SELECT @cOrderKey '@cOrderKey'
                             ,@cLOT '@cLOT'
                             ,@cLOC 'LOC'
                             ,@cID 'ID'
                             ,@cSKU 'SKU'
                             ,@cBOMSKU '@cBOMSKU'
                             ,@nQtyToTake '@nQtyToTake'
                             ,@nBOMCaseCnt '@nBOMCaseCnt'
                             ,@nQty '@nQty'
                   END

                   SELECT @b_Success = 0
                   EXECUTE nspg_getkey
                         'PickDetailKey'
                         , 10
                         , @cPickDetailKey OUTPUT
                         , @b_Success      OUTPUT
                         , @n_err          OUTPUT
                         , @c_errmsg       OUTPUT

                   -- Added By SHONG on 22-Jun-2010
                    SELECT @cPackKey = PackKey
                    FROM   SKU WITH (NOLOCK)
                    WHERE  StorerKey = @cStorerKey AND
                           SKU = @cSKU

                    INSERT PICKDETAIL
                      (
                        PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,
                        Lot, Storerkey, Sku, Qty, Loc, Id, UOMQty, UOM, CaseID,
                        PackKey, CartonGroup, DoReplenish, replenishzone,
                        docartonize, Trafficcop, PickMethod, AltSku
                      )
                    VALUES
                      (
                        @cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cLOT,
                        @cStorerKey, @cSKU, @nQtyToTake, @cLOC, @cID, @nQtyToTake / @nBOMCaseCnt,
                        '6', '', @cPackKey, 'PREPACK', 'N', '', 'N', 'U', '8', @cBOMSKU
                      )

                   UPDATE @t_QtyAvailable
                   SET    QtyAllocated = QtyAllocated+@nQtyToTake
                   WHERE  LOT = @cLOT AND
                          LOC = @cLOC AND
                          ID = @cID

                   SET @nQty = @nQty- @nQtyToTake

               END-- @@ROWCOUNT > 0
               ELSE
               BEGIN
                   -- No Stock
                   BREAK
               END
              GET_NEXT_BOM_PACKING_SKU:
              FETCH NEXT FROM C_BOM_PACKING_SKU INTO @nBOMCaseCnt, @cBOMSKU
           END -- Cursor BOM SKU
           CLOSE C_BOM_PACKING_SKU
           DEALLOCATE C_BOM_PACKING_SKU
        END --  @nQty > 0
        FETCH NEXT FROM C_BOMPackingQtyOrdLine INTO @cFacility, @cOrderKey, @cStorerKey, @cOrderLineNumber, @cSKU,
                                                    @cLottable01, @cLottable02, @dLottable04, @nQty
    END
    CLOSE C_BOMPackingQtyOrdLine
    DEALLOCATE C_BOMPackingQtyOrdLine

    -- TITAN End
    -- Allocate loose unit here
    IF @b_debug = 1
    BEGIN
       PRINT 'Start Loose Unit Allocation'
    END
    DECLARE C_LooseQtyOrdLine  CURSOR LOCAL FAST_FORWARD READ_ONLY
    FOR
        SELECT ORDERS.Facility
              ,ORDERS.OrderKey
              ,ORDERS.StorerKey
              ,ORDERDETAIL.OrderLineNumber
              ,ORDERDETAIL.SKU
              ,Lottable01
              ,Lottable02
              ,Lottable04
              ,ORDERDETAIL.OpenQty- ORDERDETAIL.QtyAllocated- ORDERDETAIL.QtyPicked AS
               Qty
        FROM   ORDERS(NOLOCK)
               JOIN ORDERDETAIL(NOLOCK)
                    ON  (ORDERDETAIL.OrderKey=ORDERS.OrderKey)
               JOIN LoadPlanDetail(NOLOCK)
                    ON  (LoadPlanDetail.OrderKey=ORDERS.OrderKey)
               JOIN SKU(NOLOCK)
                    ON  (
                            SKU.StorerKey=ORDERDETAIL.StorerKey AND
                            SKU.SKU=ORDERDETAIL.SKU
                        )
        WHERE  ORDERS.Status < '9' AND
               LoadPlanDetail.LoadKey = @c_oskey AND
               (
                   ORDERDETAIL.OpenQty- ORDERDETAIL.QtyAllocated- ORDERDETAIL.QtyPicked
               ) > 0
        ORDER BY
               ORDERDETAIL.UserDefine03
              ,ORDERS.OrderKey
              ,ORDERDETAIL.OrderLineNumber

    OPEN C_LooseQtyOrdLine

    FETCH NEXT FROM C_LooseQtyOrdLine INTO @cFacility, @cOrderKey, @cStorerKey,
    @cOrderLineNumber, @cSKU, @cLottable01, @cLottable02, @dLottable04, @nQty

    WHILE @@FETCH_STATUS <> -1
    BEGIN
        WHILE @nQty > 0
        BEGIN
            -- SET ROWCOUNT 1

            SET @cExecStatements =
                  N'SELECT TOP 1 @cLOT = LOT.LOT,
                           @cLOC = LOTxLOCxID.LOC,
                           @cID  = LOTxLOCxID.ID,
                           @nQtyAvailable = LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED
                  FROM LOT WITH (NOLOCK)
                  JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOT.LOT = LOTATTRIBUTE.LOT )
                  JOIN LOTxLOCxID WITH (NOLOCK) ON (LOTxLOCxID.LOT = LOT.LOT)
                  JOIN LOC WITH (NOLOCK) ON (LOTxLOCxID.LOC = LOC.LOC AND LOC.STATUS = ''OK'' AND
                                             LOC.LocationFlag NOT IN (''HOLD'', ''DAMAGE''))
                  JOIN ID WITH (NOLOCK) ON (LOTxLOCxID.ID = ID.ID AND ID.STATUS = ''OK'')
                  WHERE LOTxLOCxID.STORERKEY = @cStorerkey
                  AND LOTxLOCxID.SKU = @cSKU
                  AND LOT.STATUS = ''OK''
                  AND LOC.FACILITY  = @cFacility
                  AND ( LOTxLOCxID.QTY - LOTxLOCxID.QTYALLOCATED - LOTxLOCxID.QTYPICKED ) > 0 '

            IF @cLottable01 <> '' AND @cLottable01 IS NOT NULL
            BEGIN
                SET @cExecStatements = @cExecStatements +
                    ' AND LOTATTRIBUTE.Lottable01 = @cLottable01 '
            END

            IF @cLottable02 <> '' AND @cLottable02 IS NOT NULL
            BEGIN
                SET @cExecStatements = @cExecStatements +
                    ' AND LOTATTRIBUTE.Lottable02 = @cLottable02 '
            END

            IF @dLottable04 IS NOT NULL AND @dLottable04<>'19000101'
            BEGIN
                SET @cExecStatements = @cExecStatements +
                    ' AND LOTATTRIBUTE.Lottable04 = @dLottable04 '
            END

            SET @cExecStatements = @cExecStatements +
                'ORDER BY CASE WHEN LOC.LocationCategory = ''LOOSE'' THEN 1 ELSE 99 END, LOTATTRIBUTE.Lottable04, LOTATTRIBUTE.Lottable05, Loc.LogicalLocation, Loc.Loc, LOTxLOCxID.ID  '

            SET @cLOT = ''

            IF @b_debug = 1
            BEGIN
                PRINT 'Searching Qty Available'
                -- PRINT @cExecStatements
            END

            EXEC sp_executesql @cExecStatements
                ,
                 N'@cStorerkey NVARCHAR(15), @cSKU NVARCHAR(20), @cFacility NVARCHAR(5), @cLottable01 NVARCHAR(18),
                 @cLottable02 NVARCHAR(18), @dLottable04 datetime, @cLOT NVARCHAR(10) OUTPUT, @cLOC NVARCHAR(10) OUTPUT, @cID NVARCHAR(18) OUTPUT,
                 @nQtyAvailable int OUTPUT '
                ,@cStorerkey
                ,@cSKU
                ,@cFacility
                ,@cLottable01
                ,@cLottable02
                ,@dLottable04
                ,@cLOT OUTPUT
                ,@cLOC OUTPUT
                ,@cID OUTPUT
                ,@nQtyAvailable OUTPUT

            IF @cLOT IS NOT NULL AND @cLOT<>''
            BEGIN
                IF @nQtyAvailable<@nQty
                    SET @nQtyToTake = @nQtyAvailable
                ELSE
                    SET @nQtyToTake = @nQty

                IF @b_debug = 1
                BEGIN
                    PRINT 'Insert Into PickDetail for Loose Qty...'
                    SELECT @cOrderKey '@cOrderKey'
                          ,@cLOT '@cLOT'
                          ,@cLOC 'LOC'
                          ,@cID 'ID'
                          ,@cSKU 'SKU'
                          ,@cParentSKU '@cParentSKU'
                          ,@nQtyToTake '@nQtyToTake'
                END

                SELECT @b_Success = 0
                EXECUTE nspg_getkey
                      'PickDetailKey'
                      , 10
                      , @cPickDetailKey OUTPUT
                      , @b_Success      OUTPUT
                      , @n_err          OUTPUT
                      , @c_errmsg       OUTPUT

                -- Added By SHONG on 22-Jun-2010
                SELECT @cPackKey = PackKey
                FROM   SKU WITH (NOLOCK)
                WHERE  StorerKey = @cStorerKey AND
                       SKU = @cSKU

                INSERT PICKDETAIL
                  (
                    PickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                    Storerkey, Sku, Qty, Loc, Id, UOMQty, UOM, CaseID, PackKey,
                    CartonGroup, DoReplenish, replenishzone, docartonize,
                    Trafficcop, PickMethod
                  )
                VALUES
                  (
                    @cPickDetailKey, '', @cOrderKey, @cOrderLineNumber, @cLOT, @cStorerKey,
                    @cSKU, @nQtyToTake, @cLOC, @cID, @nQtyToTake, '6', '', @cPackKey,
                    '', 'N', '', 'N', 'U', '8'
                  )

                UPDATE @t_QtyAvailable
                SET    QtyAllocated = QtyAllocated+@nQtyToTake
                WHERE  LOT = @cLOT AND
                       LOC = @cLOC AND
                       ID = @cID

                SET @nQty = @nQty- @nQtyToTake
            END-- @@ROWCOUNT > 0
            ELSE
            BEGIN
                -- No Stock
                BREAK
            END
        END --  @nQty > 0
        FETCH NEXT FROM C_LooseQtyOrdLine INTO @cFacility, @cOrderKey, @cStorerKey,
        @cOrderLineNumber,
        @cSKU, @cLottable01, @cLottable02, @dLottable04, @nQty
    END
    CLOSE C_LooseQtyOrdLine
    DEALLOCATE C_LooseQtyOrdLine

    SP_RETURN:
END

GO