SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispExportAllocatedOrd                                 */
/* Creation Date:                                                          */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: Allocated/Pre-Pick trigger point for E1 Orders & other         */
/*          respective storer.                                             */
/*                                                                         */
/* Called By: None                                                         */
/*                                                                         */
/* Parameters: (Input)  @c_Key     = LoadKey / WaveKey                     */
/*                      @c_Type    = LOADPLAN / WAVE                       */
/*                                                                         */
/* PVCS Version: 1.6                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 25-Aug-2008  YokeBeen  1.1   FBR#113389 - Added for IDSMY CADBURY       */
/*                              interface trigger point. - (YokeBeen01)    */
/* 11-Mar-2009  Yokebeen  1.2   - Moved the Condition check for Loadplan   */
/*                                on Orders.Userdefine08 into the cursor   */
/*                                variable.                                */
/*                              - Added in the Generic Trigger point of    */
/*                                "ALLOCLOG" for Allocation or upon        */
/*                                PickSlip Printing. - (YokeBeen02)        */
/* 28-May-2009  Leong     1.2   SOS#137918 - Bug Fix for "ALLOCLOG"        */
/* 30-Jul-2009  Shong     1.3   SOS#143653 - Send Zero Pick Confirmed when */
/*                              required.                                  */
/* 22-Dec-2010	 YokeBeen  1.4   SOS#198768 - Blocked interface on process  */
/*                              of re-allocation with Configkey = 'GDSITF'.*/
/*                              Changed to have new ConfigKey = "ORDALLOC".*/
/*                              Changed key values for TransmitLog table.  */
/*                              - (YokeBeen03)                             */
/* 12-Mar-2011  Leong     1.5   SOS# 238613 - Check Svalue = '1'           */
/* 03-Sep-2012  YokeBeen  1.6   SOS#245001 - Added StorerConfig.ConfigKey  */
/*                              "AllowResetFlagOfTL3" to reset flag "IGNOR"*/
/*                              to "0" - Open for interface process.       */
/*                              - (YokeBeen04)                             */
/* 25-Jul-2017  TLTING    1.7   Remove SETROWCOUNT                         */
/* 20-Dec-2018  TLTING    1.8   MIssing nolock                             */
/* 12-Jul-2023  WLChooi   1.9   WMS-22860 - Trigger TL2 (WL01)             */
/* 12-Jul-2023  WLChooi   1.9   DevOps Combine Script                      */
/***************************************************************************/

CREATE   PROCEDURE [dbo].[ispExportAllocatedOrd]
   @c_Key     NVARCHAR(10)
 , @c_Type    NVARCHAR(10)
 , @b_success INT           OUTPUT
 , @n_err     INT           OUTPUT
 , @c_errmsg  NVARCHAR(225) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue INT

   DECLARE @c_ExternOrdKey                NVARCHAR(20)
         , @c_ExternLineNo                NVARCHAR(10)
         , @c_OrderKey                    NVARCHAR(10)
         , @c_orderline                   NVARCHAR(5)
         , @c_transmitlogkey              NVARCHAR(10)
         , @c_StorerKey                   NVARCHAR(15)
         , @c_OrderType                   NVARCHAR(10)
         , @c_tablename                   NVARCHAR(20)
         , @c_Userdefine08                NVARCHAR(10) -- (YokeBeen02)
         , @c_ALLOCLOG                    NVARCHAR(1) -- (YokeBeen02)
         , @c_AllowResetALLOCLOGFlagOfTL3 NVARCHAR(1) -- (YokeBeen04)    
         , @c_WSALLOCLOG                  NVARCHAR(10) = ''     --WL01
         , @c_AllowResetTL2               NVARCHAR(10) = ''     --WL01
         , @c_Option5                     NVARCHAR(4000) = ''   --WL01

   SELECT @n_continue = 1
        , @b_success = 1

   -- Added By Shong for Allocation Confirm
   -- Modify By Shong for OW Phase II
   -- Modify By June 7.Jan.01 for OW Phase II
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_type = 'LOADPLAN'
      BEGIN
         SELECT @c_OrderKey = N'' -- Changed by June 7.Jan.01 for OW Phase II

         WHILE 1 = 1
         BEGIN

            SELECT TOP 1 @c_OrderKey = ORDERS.OrderKey
                       , @c_ExternOrdKey = ORDERS.ExternOrderkey -- Added By June 7.Jan.01 for OW Phase II
                       , @c_StorerKey = ORDERS.StorerKey
                       , @c_OrderType = ORDERS.Type
                       , @c_Userdefine08 = ORDERS.Userdefine08 -- (YokeBeen02)
            FROM LOADPLANDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey)
            WHERE ORDERS.OrderKey > @c_OrderKey AND LOADPLANDETAIL.LoadKey = @c_Key AND ORDERS.Status <> '9'
            --    			and	 orders.userdefine08 <> 'Y' -- SOS 7711 wally 28.aug.2002 do not include processed orders in wave
            ORDER BY ORDERS.OrderKey

            IF @@ROWCOUNT = 0
               BREAK

            -- (YokeBeen02) - Start
            IF ISNULL(RTRIM(@c_Userdefine08), '') <> 'Y'
            BEGIN
               -- Get Storer Configuration -- One World Interface
               -- Is One World Interface Turn On?
               IF EXISTS (  SELECT 1
                            FROM StorerConfig WITH (NOLOCK)
                            WHERE StorerKey = @c_StorerKey AND ConfigKey = 'OWITF' AND sValue = '1')
               BEGIN
                  -- Start - Add by June 29.Jan.02 FBR039
                  IF EXISTS (  SELECT 1
                               FROM StorerConfig WITH (NOLOCK)
                               WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ALLOC-TRF' AND sValue = '1')
                  BEGIN -- End - Add by June 29.Jan.02 FBR039
                     IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') <> 'M'
                     BEGIN
                        IF NOT EXISTS (  SELECT Key1
                                         FROM TransmitLog WITH (NOLOCK)
                                         WHERE TableName = 'OWORDALLOC' AND Key1 = @c_OrderKey)
                        BEGIN
                           SELECT @c_transmitlogkey = N''
                           SELECT @b_success = 1

                           EXECUTE nspg_getkey 'TransmitlogKey'
                                             , 10
                                             , @c_transmitlogkey OUTPUT
                                             , @b_success OUTPUT
                                             , @n_err OUTPUT
                                             , @c_errmsg OUTPUT

                           IF @b_success = 1
                           BEGIN
                              INSERT INTO TRANSMITLOG (transmitlogkey, tablename, key1, key2, key3, transmitflag
                                                     , transmitbatch)
                              VALUES (@c_transmitlogkey, 'OWORDALLOC', @c_OrderKey, '', '', '0', '')
                           END
                        END -- not in transmit log
                     END -- IF @c_OrderType IN ('CD','N','O')
                  END -- ALLOC-TRF Add by June 31.Jan.02 FBR039
               END -- OW Interface
               ELSE
               BEGIN
                  IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') IN ( 'CD', 'N', 'O', '1', '2', '5', '6' )
                  BEGIN
                     IF ISNULL(dbo.fnc_RTrim(@c_ExternOrdKey), '') <> ''
                     BEGIN
                        -- (YokeBeen03) - Start - Changed on obsolete Configkey = 'GDSITF' to 'ORDALLOC' and key values.
                        -- Added By SHONG 26th Jun 2002
                        IF EXISTS (  SELECT 1
                                     FROM StorerConfig WITH (NOLOCK)
                                     WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ORDALLOC' AND sValue = '1')
                        --             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'GDSITF' AND sValue = '1' )
                        BEGIN
                           IF NOT EXISTS (  SELECT Key1
                                            FROM TransmitLog WITH (NOLOCK)
                                            WHERE TableName = 'ORDALLOC'
                                            AND   Key1 = @c_OrderKey
                                            AND   Key2 = @c_OrderType
                                            AND   Key3 = @c_StorerKey)
                           --                    WHERE TableName = 'ORDALLOC' AND Key1 = @c_ExternOrdKey )
                           BEGIN
                              SELECT @c_transmitlogkey = N''
                              SELECT @b_success = 1

                              EXECUTE nspg_getkey 'TransmitlogKey'
                                                , 10
                                                , @c_transmitlogkey OUTPUT
                                                , @b_success OUTPUT
                                                , @n_err OUTPUT
                                                , @c_errmsg OUTPUT

                              IF @b_success = 1
                              BEGIN
                                 INSERT INTO TRANSMITLOG (transmitlogkey, tablename, key1, key2, key3, transmitflag
                                                        , transmitbatch)
                                 VALUES (@c_transmitlogkey, 'ORDALLOC', @c_OrderKey, @c_OrderType, @c_StorerKey, '0'
                                       , '')
                              --         VALUES (@c_transmitlogkey, 'ORDALLOC', @c_ExternOrdKey, '', '', '0', '')
                              END
                           END -- not in transmit log
                        END -- if GDSITF turn on
                     -- (YokeBeen03) - End - Changed on obsolete Configkey = 'GDSITF' to 'ORDALLOC' and key values.
                     END -- if extern orderkey <> BLANK
                  END -- IF @c_OrderType IN ('CD','N','O')
               END -- GDS Interface

               -- (YokeBeen01) - Start (IDSMY CADBURY Interface)
               IF EXISTS (  SELECT 1
                            FROM STORERCONFIG WITH (NOLOCK)
                            WHERE StorerKey = @c_StorerKey AND ConfigKey = 'CADITF' AND sValue = '1')
               BEGIN
                  IF ISNULL(RTRIM(@c_OrderType), '') <> ('M')
                  BEGIN
                     EXEC ispGenTransmitLog3 'ORDALLOC'
                                           , @c_OrderKey
                                           , ''
                                           , @c_StorerKey
                                           , ''
                                           , @b_success OUTPUT
                                           , @n_err OUTPUT
                                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                     END
                  END -- IF @c_OrderType <> ('M')
               END -- if CADITF turn on
               --SOS#137918 Start
               ELSE
               BEGIN
                  SELECT @c_ALLOCLOG = 0
                  SELECT @b_success = 0

                  EXECUTE nspGetRight NULL -- Facility
                                    , @c_StorerKey -- Storerkey
                                    , NULL -- Sku
                                    , 'ALLOCLOG' -- Configkey
                                    , @b_success OUTPUT
                                    , @c_ALLOCLOG OUTPUT
                                    , @n_err OUTPUT
                                    , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                          , @c_errmsg = 'ispExportAllocatedOrd' + dbo.fnc_RTrim(@c_errmsg)
                  END

                  IF @b_success = 1 AND @c_ALLOCLOG = '1'
                  BEGIN
                     -- (YokeBeen04) - Start  
                     IF NOT EXISTS (  SELECT Key1
                                      FROM TransmitLog3 WITH (NOLOCK)
                                      WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey)
                     BEGIN
                        EXEC ispGenTransmitLog3 'ALLOCLOG'
                                              , @c_OrderKey
                                              , @c_OrderType
                                              , @c_StorerKey
                                              , ''
                                              , @b_success OUTPUT
                                              , @n_err OUTPUT
                                              , @c_errmsg OUTPUT

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                , @n_err = 63800
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                              + ': Unable to Generate TransmitLog3 Record, TableName = ALLOCLOG (ispExportAllocatedOrd)'
                                              + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                        END
                     END -- IF NOT EXISTS in TransmitLog3  
                     ELSE
                     BEGIN -- IF EXISTS in TransmitLog3  
                        SELECT @c_AllowResetALLOCLOGFlagOfTL3 = 0
                        SELECT @b_success = 0

                        EXECUTE nspGetRight NULL -- Facility  
                                          , @c_StorerKey -- Storerkey  
                                          , NULL -- Sku  
                                          , 'AllowResetALLOCLOGFlagOfTL3' -- Configkey  
                                          , @b_success OUTPUT
                                          , @c_AllowResetALLOCLOGFlagOfTL3 OUTPUT
                                          , @n_err OUTPUT
                                          , @c_errmsg OUTPUT

                        -- Reset TransmitFlag = "0" if record exists  
                        IF @c_AllowResetALLOCLOGFlagOfTL3 = '1'
                        BEGIN
                           IF EXISTS (  SELECT Key1
                                        FROM TransmitLog3 WITH (NOLOCK)
                                        WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR')
                           BEGIN
                              UPDATE TransmitLog3 WITH (ROWLOCK)
                              SET TransmitFlag = '0'
                              WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR'
                           END
                           ELSE
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                   , @n_err = 63801
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                                 + ': Unable to Update TransmitLog3 Record, TableName = ALLOCLOG (ispExportAllocatedOrd), Record already processed.'
                                                 + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                           END
                        END -- IF @c_AllowResetALLOCLOGFlagOfTL3 = '1'  
                     END -- IF EXISTS in TransmitLog3  
                  -- (YokeBeen04) - End  
                  END -- IF @b_success = 1 AND @c_ALLOCLOG = '1'
               END -- IF ISNULL(RTRIM(@c_Userdefine08),'') = 'Y'
               --SOS#137918 End
               -- (YokeBeen01) - End

               --WL01 S
               IF @n_continue = 1 OR @n_continue = 2
               BEGIN
                  SELECT @c_WSALLOCLOG = 0
                  SELECT @b_success = 0
              
                  EXEC dbo.nspGetRight @c_Facility = NULL
                                     , @c_StorerKey = @c_StorerKey
                                     , @c_sku = NULL
                                     , @c_ConfigKey = N'WSALLOCLOG'
                                     , @b_Success = @b_Success OUTPUT
                                     , @c_authority = @c_WSALLOCLOG OUTPUT
                                     , @n_err = @n_err OUTPUT
                                     , @c_errmsg = @c_errmsg OUTPUT
                                     , @c_Option5 = @c_Option5 OUTPUT
                  
                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                          , @c_errmsg = 'ispExportAllocatedOrd' + dbo.fnc_RTrim(@c_errmsg)
                  END
              
                  IF @b_success = 1 AND @c_WSALLOCLOG = '1'
                  BEGIN
                     SET @c_Tablename = ''
                     SELECT @c_Tablename = dbo.fnc_GetParamValueFromString('@c_Tablename', @c_Option5, @c_Tablename)
              
                     IF ISNULL(@c_Tablename,'') = ''
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                             , @n_err = 63808
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                           + ': Tablename not set up in Storerconfig.Option5. (ispExportAllocatedOrd)'
                                           + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                     END
              
                     IF (@n_continue = 1 OR @n_continue = 2)
                     BEGIN
                        IF NOT EXISTS (  SELECT Key1
                                         FROM TransmitLog2 WITH (NOLOCK)
                                         WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey)
                        BEGIN
                           EXEC dbo.ispGenTransmitLog2 @c_TableName = @c_Tablename
                                                     , @c_Key1 = @c_OrderKey
                                                     , @c_Key2 = N''
                                                     , @c_Key3 = @c_StorerKey
                                                     , @c_TransmitBatch = N''
                                                     , @b_Success = @b_Success OUTPUT
                                                     , @n_err = @n_err OUTPUT
                                                     , @c_errmsg = @c_errmsg OUTPUT
                        
              
                           IF @b_success <> 1
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                   , @n_err = 63809
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                                 + ': Unable to Generate TransmitLog2 Record, TableName = ' + @c_Tablename + ' (ispExportAllocatedOrd)'
                                                 + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                           END
                        END -- IF NOT EXISTS in TransmitLog2 
                        ELSE
                        BEGIN -- IF EXISTS in TransmitLog2  
                           SELECT @c_AllowResetTL2 = '0'
                           SELECT @c_AllowResetTL2 = dbo.fnc_GetParamValueFromString('@c_AllowResetTL2', @c_Option5, @c_AllowResetTL2)
              
                           -- Reset TransmitFlag = '0' if record exists  
                           IF @c_AllowResetTL2 = '1'
                           BEGIN
                              IF EXISTS (  SELECT Key1
                                           FROM TransmitLog2 WITH (NOLOCK)
                                           WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR')
                              BEGIN
                                 UPDATE TransmitLog2 WITH (ROWLOCK)
                                 SET TransmitFlag = '0'
                                 WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR'
                              END
                              ELSE
                              BEGIN
                                 SELECT @n_continue = 3
                                 SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                      , @n_err = 63810
                                 SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                                    + ': Unable to Update TransmitLog2 Record, TableName = ' + @c_Tablename + ' (ispExportAllocatedOrd), Record already processed.'
                                                    + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                              END
                           END -- IF @c_AllowResetWSALLOCLOGFlagOfTL2 = '1'  
                        END -- IF EXISTS in TransmitLog2  
                     END
                  END -- IF @b_success = 1 AND @c_WSALLOCLOG = '1'
               END -- IF @n_continue = 1 or @n_continue=2
               --WL01 E

               --SOS#143653 Start
               --tlting01
               IF EXISTS (  SELECT 1
                            FROM StorerConfig (NOLOCK)
                            WHERE StorerKey = @c_StorerKey AND ConfigKey = 'PICKCFMLOG' AND SValue = '1') -- SOS# 238613
               BEGIN
                  IF EXISTS (  SELECT 1
                               FROM StorerConfig (NOLOCK)
                               WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ZEROPICKCFMLOG' AND SValue = '1') -- SOS# 238613

                  BEGIN
                     IF NOT EXISTS (  SELECT 1
                                      FROM PICKDETAIL (NOLOCK)
                                      WHERE OrderKey = @c_OrderKey)
                     BEGIN
                        EXEC dbo.ispGenTransmitLog3 'PICKCFMLOG'
                                                  , @c_OrderKey
                                                  , ''
                                                  , @c_StorerKey
                                                  , ''
                                                  , @b_success OUTPUT
                                                  , @n_err OUTPUT
                                                  , @c_errmsg OUTPUT
                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                , @n_err = 63800
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                              + ': Unable to Generate TransmitLog3 Record, TableName = ZEROPICKCFMLOG (ispExportAllocatedOrd)'
                                              + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                        END
                     END
                  END
               END -- PICKCFMLOG
            --SOS#143653 End

            END -- IF ISNULL(RTRIM(@c_Userdefine08),'') <> 'Y'
         -- (YokeBeen02) - End
         END -- WHILE 1=1
      END -- @c_type = loadplan
   END -- @n_continue = 1 or @n_continue=2

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @c_type = 'WAVE'
      BEGIN
         SELECT @c_OrderKey = N'' -- Added By June 7.Jan.01 for OW Phase II

         WHILE 1 = 1
         BEGIN
            SELECT TOP 1 @c_OrderKey = ORDERS.OrderKey
                       , @c_ExternOrdKey = ORDERS.ExternOrderkey -- Added By June 7.Jan.01 for OW Phase II
                       , @c_StorerKey = ORDERS.StorerKey
                       , @c_OrderType = ORDERS.Type
            FROM WAVEDETAIL WITH (NOLOCK)
            JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey)
            WHERE ORDERS.OrderKey > @c_OrderKey AND WAVEDETAIL.WaveKey = @c_Key AND ORDERS.Status <> '9'
            ORDER BY ORDERS.OrderKey

            IF @@ROWCOUNT = 0
               BREAK

            -- Get Storer Configuration -- One World Interface
            -- Is One World Interface Turn On?
            IF EXISTS (  SELECT 1
                         FROM StorerConfig WITH (NOLOCK)
                         WHERE StorerKey = @c_StorerKey AND ConfigKey = 'OWITF' AND sValue = '1')
            BEGIN
               -- If DPREPICK / DPREPICK+1 flag is ON, use 'OWPREPICK' tablename
               -- Otherwise, insert 'OWORDALLOC' tablename when ALLOC-ITF flag is ON
               -- Start - Add by June 8.Aug.02
               IF EXISTS (  SELECT 1
                            FROM StorerConfig WITH (NOLOCK)
                            WHERE StorerKey = @c_StorerKey
                            AND   ConfigKey IN ( 'DPREPICK', 'DPREPICK+1' )
                            AND   sValue = '1')
               BEGIN
                  IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') <> 'M'
                  BEGIN
                     IF NOT EXISTS (  SELECT Key1
                                      FROM TransmitLog WITH (NOLOCK)
                                      WHERE TableName = 'OWDPREPICK' AND Key1 = @c_OrderKey)
                     BEGIN
                        SELECT @c_transmitlogkey = N''
                        SELECT @b_success = 1

                        EXECUTE nspg_getkey 'TransmitlogKey'
                                          , 10
                                          , @c_transmitlogkey OUTPUT
                                          , @b_success OUTPUT
                                          , @n_err OUTPUT
                                          , @c_errmsg OUTPUT

                        IF @b_success = 1
                        BEGIN
                           INSERT INTO TRANSMITLOG (transmitlogkey, tablename, key1, key2, key3, transmitflag
                                                  , transmitbatch)
                           VALUES (@c_transmitlogkey, 'OWDPREPICK', @c_OrderKey, '', '', '0', '')
                        END
                     END -- if exists
                  END -- @c_OrderType IN ('CD','N','O')
               END -- 'DISCRETE_PRE_PICK', 'DISCRETE_PRE_PICK+1'
               ELSE
               BEGIN -- End - Add by June 8.Aug.02
                  -- Start - Add by June 29.Jan.02 FBR039
                  IF EXISTS (  SELECT 1
                               FROM StorerConfig WITH (NOLOCK)
                               WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ALLOC-TRF' AND sValue = '1')
                  BEGIN -- End - Add by June 29.Jan.02 FBR039
                     IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') <> 'M'
                     BEGIN
                        IF NOT EXISTS (  SELECT Key1
                                         FROM TransmitLog WITH (NOLOCK)
                                         WHERE TableName = 'OWORDALLOC' AND Key1 = @c_OrderKey)
                        BEGIN
                           SELECT @c_transmitlogkey = N''
                           SELECT @b_success = 1

                           EXECUTE nspg_getkey 'TransmitlogKey'
                                             , 10
                                             , @c_transmitlogkey OUTPUT
                                             , @b_success OUTPUT
                                             , @n_err OUTPUT
                                             , @c_errmsg OUTPUT

                           IF @b_success = 1
                           BEGIN
                              INSERT INTO TRANSMITLOG (transmitlogkey, tablename, key1, key2, key3, transmitflag
                                                     , transmitbatch)
                              VALUES (@c_transmitlogkey, 'OWORDALLOC', @c_OrderKey, '', '', '0', '')
                           END
                        END -- if exists
                     END -- @c_OrderType IN ('CD','N','O')
                  END -- if exists 'ALLOC-TRF'
               END -- ALLOC-TRF
            END -- One World interface
            ELSE
            BEGIN
               IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') IN ( 'CD', 'N', 'O', '1', '2', '5', '6' )
               BEGIN
                  -- (YokeBeen03) - Start - Changed on obsolete Configkey = 'GDSITF' to 'ORDALLOC' and key values.
                  -- Added By SHONG 26th Jun 2002
                  IF EXISTS (  SELECT 1
                               FROM StorerConfig WITH (NOLOCK)
                               WHERE StorerKey = @c_StorerKey AND ConfigKey = 'ORDALLOC' AND sValue = '1')
                  --             WHERE StorerKey = @c_StorerKey AND ConfigKey = 'GDSITF' AND sValue = '1' )
                  BEGIN
                     IF NOT EXISTS (  SELECT Key1
                                      FROM TransmitLog WITH (NOLOCK)
                                      WHERE TableName = 'ORDALLOC'
                                      AND   Key1 = @c_OrderKey
                                      AND   Key2 = @c_OrderType
                                      AND   Key3 = @c_StorerKey)
                     --                 WHERE TableName = 'ORDALLOC' AND Key1 = @c_ExternOrdKey )
                     BEGIN
                        SELECT @c_transmitlogkey = N''
                        SELECT @b_success = 1

                        EXECUTE nspg_getkey 'TransmitlogKey'
                                          , 10
                                          , @c_transmitlogkey OUTPUT
                                          , @b_success OUTPUT
                                          , @n_err OUTPUT
                                          , @c_errmsg OUTPUT

                        IF @b_success = 1
                        BEGIN
                           INSERT INTO TRANSMITLOG (transmitlogkey, tablename, key1, key2, key3, transmitflag
                                                  , transmitbatch)
                           VALUES (@c_transmitlogkey, 'ORDALLOC', @c_OrderKey, @c_OrderType, @c_StorerKey, '0', '')
                        --         VALUES (@c_transmitlogkey, 'ORDALLOC', @c_ExternOrdKey, '', '', '0', '')
                        END
                     END -- if exists
                  END -- if GDSITF Turn ON
               -- (YokeBeen03) - Start - Changed on obsolete Configkey = 'GDSITF' to 'ORDALLOC' and key values.
               END -- @c_OrderType IN ('CD','N','O')
            END -- GDS interface

            -- (YokeBeen01) - Start (IDSMY CADBURY Interface)
            IF EXISTS (  SELECT 1
                         FROM STORERCONFIG WITH (NOLOCK)
                         WHERE StorerKey = @c_StorerKey AND ConfigKey = 'CADITF' AND sValue = '1')
            BEGIN
               IF ISNULL(dbo.fnc_RTrim(@c_OrderType), '') <> ('M')
               BEGIN
                  EXEC ispGenTransmitLog3 'ORDALLOC'
                                        , @c_OrderKey
                                        , ''
                                        , @c_StorerKey
                                        , ''
                                        , @b_success OUTPUT
                                        , @n_err OUTPUT
                                        , @c_errmsg OUTPUT

                  IF @b_success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
               END -- IF @c_OrderType <> ('M')
            END -- if CADITF turn on
            -- (YokeBeen01) - End

            -- (YokeBeen02) - Start
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @c_ALLOCLOG = 0
               SELECT @b_success = 0

               EXECUTE nspGetRight NULL -- Facility
                                 , @c_StorerKey -- Storerkey
                                 , NULL -- Sku
                                 , 'ALLOCLOG' -- Configkey
                                 , @b_success OUTPUT
                                 , @c_ALLOCLOG OUTPUT
                                 , @n_err OUTPUT
                                 , @c_errmsg OUTPUT

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                       , @c_errmsg = 'ispExportAllocatedOrd' + dbo.fnc_RTrim(@c_errmsg)
               END

               IF @b_success = 1 AND @c_ALLOCLOG = '1'
               BEGIN
                  -- (YokeBeen04) - Start  
                  IF NOT EXISTS (  SELECT Key1
                                   FROM TransmitLog3 WITH (NOLOCK)
                                   WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey)
                  BEGIN
                     EXEC ispGenTransmitLog3 'ALLOCLOG'
                                           , @c_OrderKey
                                           , @c_OrderType
                                           , @c_StorerKey
                                           , ''
                                           , @b_success OUTPUT
                                           , @n_err OUTPUT
                                           , @c_errmsg OUTPUT

                     IF @b_success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                             , @n_err = 63803
                        SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                           + ': Unable to Generate TransmitLog3 Record, TableName = ALLOCLOG (ispExportAllocatedOrd)'
                                           + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                     END
                  END -- IF NOT EXISTS in TransmitLog3  
                  ELSE
                  BEGIN -- IF EXISTS in TransmitLog3  
                     SELECT @c_AllowResetALLOCLOGFlagOfTL3 = 0
                     SELECT @b_success = 0

                     EXECUTE nspGetRight NULL -- Facility  
                                       , @c_StorerKey -- Storerkey  
                                       , NULL -- Sku  
                                       , 'AllowResetALLOCLOGFlagOfTL3' -- Configkey  
                                       , @b_success OUTPUT
                                       , @c_AllowResetALLOCLOGFlagOfTL3 OUTPUT
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT

                     -- Reset TransmitFlag = "0" if record exists  
                     IF @c_AllowResetALLOCLOGFlagOfTL3 = '1'
                     BEGIN
                        IF EXISTS (  SELECT Key1
                                     FROM TransmitLog3 WITH (NOLOCK)
                                     WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR')
                        BEGIN
                           UPDATE TransmitLog3 WITH (ROWLOCK)
                           SET TransmitFlag = '0'
                           WHERE TableName = 'ALLOCLOG' AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR'
                        END
                        ELSE
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                , @n_err = 63804
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                              + ': Unable to Update TransmitLog3 Record, TableName = ALLOCLOG (ispExportAllocatedOrd), Record already processed.'
                                              + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                        END
                     END -- IF @c_AllowResetALLOCLOGFlagOfTL3 = '1'  
                  END -- IF EXISTS in TransmitLog3  
               -- (YokeBeen04) - End  
               END -- IF @b_success = 1 AND @c_ALLOCLOG = '1'
            END -- IF @n_continue = 1 or @n_continue=2

            --WL01 S
            IF @n_continue = 1 OR @n_continue = 2
            BEGIN
               SELECT @c_WSALLOCLOG = 0
               SELECT @b_success = 0

               EXEC dbo.nspGetRight @c_Facility = NULL
                                  , @c_StorerKey = @c_StorerKey
                                  , @c_sku = NULL
                                  , @c_ConfigKey = N'WSALLOCLOG'
                                  , @b_Success = @b_Success OUTPUT
                                  , @c_authority = @c_WSALLOCLOG OUTPUT
                                  , @n_err = @n_err OUTPUT
                                  , @c_errmsg = @c_errmsg OUTPUT
                                  , @c_Option5 = @c_Option5 OUTPUT
               
               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                       , @c_errmsg = 'ispExportAllocatedOrd' + dbo.fnc_RTrim(@c_errmsg)
               END

               IF @b_success = 1 AND @c_WSALLOCLOG = '1'
               BEGIN
                  SET @c_Tablename = ''
                  SELECT @c_Tablename = dbo.fnc_GetParamValueFromString('@c_Tablename', @c_Option5, @c_Tablename)

                  IF ISNULL(@c_Tablename,'') = ''
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                          , @n_err = 63805
                     SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                        + ': Tablename not set up in Storerconfig.Option5. (ispExportAllocatedOrd)'
                                        + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                  END

                  IF (@n_continue = 1 OR @n_continue = 2)
                  BEGIN
                     IF NOT EXISTS (  SELECT Key1
                                      FROM TransmitLog2 WITH (NOLOCK)
                                      WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey)
                     BEGIN
                        EXEC dbo.ispGenTransmitLog2 @c_TableName = @c_Tablename
                                                  , @c_Key1 = @c_OrderKey
                                                  , @c_Key2 = N''
                                                  , @c_Key3 = @c_StorerKey
                                                  , @c_TransmitBatch = N''
                                                  , @b_Success = @b_Success OUTPUT
                                                  , @n_err = @n_err OUTPUT
                                                  , @c_errmsg = @c_errmsg OUTPUT
                     

                        IF @b_success <> 1
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                , @n_err = 63806
                           SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                              + ': Unable to Generate TransmitLog2 Record, TableName = ' + @c_Tablename + ' (ispExportAllocatedOrd)'
                                              + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                        END
                     END -- IF NOT EXISTS in TransmitLog2 
                     ELSE
                     BEGIN -- IF EXISTS in TransmitLog2  
                        SELECT @c_AllowResetTL2 = '0'
                        SELECT @c_AllowResetTL2 = dbo.fnc_GetParamValueFromString('@c_AllowResetTL2', @c_Option5, @c_AllowResetTL2)

                        -- Reset TransmitFlag = '0' if record exists  
                        IF @c_AllowResetTL2 = '1'
                        BEGIN
                           IF EXISTS (  SELECT Key1
                                        FROM TransmitLog2 WITH (NOLOCK)
                                        WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR')
                           BEGIN
                              UPDATE TransmitLog2 WITH (ROWLOCK)
                              SET TransmitFlag = '0'
                              WHERE TableName = @c_Tablename AND Key1 = @c_OrderKey AND TransmitFlag = 'IGNOR'
                           END
                           ELSE
                           BEGIN
                              SELECT @n_continue = 3
                              SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                                   , @n_err = 63807
                              SELECT @c_errmsg = 'NSQL' + CONVERT(CHAR(5), ISNULL(@n_err, 0))
                                                 + ': Unable to Update TransmitLog2 Record, TableName = ' + @c_Tablename + ' (ispExportAllocatedOrd), Record already processed.'
                                                 + ' ( SQLSvr MESSAGE=' + ISNULL(LTRIM(RTRIM(@c_errmsg)), '') + ' ) '
                           END
                        END -- IF @c_AllowResetWSALLOCLOGFlagOfTL2 = '1'  
                     END -- IF EXISTS in TransmitLog2  
                  END
               END -- IF @b_success = 1 AND @c_WSALLOCLOG = '1'
            END -- IF @n_continue = 1 or @n_continue=2
            --WL01 E

         -- (YokeBeen02) - Start
         END /* WHILE 1=1 */
      END -- @c_type = wave
   END -- @n_continue = 1 or @n_continue=2
END -- End PROC

GO