SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispWAVRL01                                         */
/* Creation Date: 15-Nov-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#230381 - Release Wave To WCS                            */
/*          Storerconfig WAVERESLOG=1 to insert wave record into        */
/*          transmitlog3                                                */
/*                                                                      */
/* Input Parameters:  @c_Wavekey  - (Wave #)                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: isp_WaveReleaseToWCS_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 2012-01-12   ChewKP   1.1  Insert PICKRESLOG to TransmitLog3         */
/*                            (ChewKP01)                                */
/* 2012-03-13   ChewKP   1.2  Create PickHeader (ChewKP02)              */
/* 2012-03-31   James    1.3  Clear Pickdetail.CaseID  (james01)        */
/* 2012-04-06   Shong    1.4  Added Validation For Aigle and SKU        */
/* 2012-04-07   James    1.5  If config WAVEUPDLOG not turned on then   */
/*                            cannot re-release wave (james02)          */
/* 2012-04-09   Shong    1.6  Add Validation for Non UCC                */
/* 2012-04-16   Shong    1.7  Doing Risidual Move for Non-Full Carton   */
/* 2012-04-16   Shong    1.8  Added Non UCC Location Code into Err Msg  */
/* 2012-05-02   Shong    1.9  Added ReddWerk Validation                 */
/* 2012-06-18   Shong    2.0  Delete PreAllocatePickDetail              */
/* 2012-07-04   Shong    2.1  Added Validation Error Log                */
/* 2012-08-01   ChewKP   2.2  Add TraceInfo (ChewKP03)                  */
/* 2012-08-09   YTWan    2.3  SOS#251460-Release WAVE Error Log. Call   */
/*                            From ispWVRLE01. (Wan01)                  */
/* 2012-10-22   NJOW01   2.4  257389-FNPC Auto MBOL Creation            */
/* 2013-02-13   YTWan    2.5  SOS#270109:Wave with multiple storerkeys  */
/*                            (Wan02)                                   */
/* 2012-09-25   Shong    2.6  Move Residual Qty for Last Carton         */
/* 05-10-2013   Shong    2.7  Change Declare Cursor to LOCAL            */
/* 01-08-2014   CSCHONG  2.8  Added Lottables 06-15 (CS01)              */
/************************************************************************/

CREATE PROC [dbo].[ispWAVRL01] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
  ,@b_ValidateOnly   INT = 0           --(Wan01)
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTranCnt    INT
         , @c_errmsg2         NVARCHAR(250)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Configkey       NVARCHAR(10)
         , @c_SValue          NVARCHAR(10)
         , @c_TransmitlogKey  NVARCHAR(10)

         , @c_authority_pickreslog CHAR(1) -- Generic Pick Release Interface -- (ChewKP01)
         , @c_OrderKey        NVARCHAR(10) -- (ChewKP01)
         , @c_ConsoOrderKey   NVARCHAR(30) -- (ChewKP02)
         , @c_PickSlipNo      NVARCHAR(10) -- (ChewKP02)
         , @c_ErrMsg3         NVARCHAR(255)--(Wan02)

   SET @n_StartTranCnt  =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @c_Storerkey     = ''
   SET @c_Configkey     = 'WAVERESLOG'
   SET @c_SValue        = ''
   SET @c_TransmitlogKey= ''
   SET @c_ErrMsg2       = ''
   SET @c_ErrMsg3       = ''              --(Wan02)

   DELETE [WaveRelErrorReport] WHERE WaveKey = @c_WaveKey



--   IF EXISTS (SELECT 1
--              FROM WAVEDETAIL WD WITH (NOLOCK)
--              JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.Orderkey = WD.Orderkey)
--              JOIN SKU SKU WITH (NOLOCK) ON (SKU.Storerkey = OD.Storerkey)
--                                         AND(SKU.Sku = OD.Sku)
--              WHERE WD.Wavekey = @c_WaveKey
--              AND (SKU.Length= 0
--              OR   SKU.Width = 0
--              OR   SKU.Height= 0
--              OR   SKU.StdGrossWgt = 0))
--   BEGIN
--      SET @n_continue = 3
--      SET @n_Err = 31301
--      SEt @c_ErrMsg = 'There is product not setup lenght, width, height or Gross Weight in wave: ' + @c_WaveKey
--                    + '. (ispWAVRL01)'
--      GOTO RETURN_SP
--   END

   DECLARE @c_NonUCCLocation NVARCHAR(10)

   SET @c_NonUCCLocation = ''
   SET @c_ErrMsg = ''

   IF EXISTS(SELECT  1 FROM  dbo.WAVEDETAIL WD WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey=WD.OrderKey)
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON  (
                  OD.StorerKey=PD.StorerKey
              AND OD.OrderKey=PD.OrderKey
              AND OD.OrderLineNumber=PD.OrderLineNumber)
         LEFT JOIN dbo.UCC UCC WITH (NOLOCK) ON  (
                  PD.StorerKey=UCC.StorerKey
              AND PD.SKU=UCC.SKU
              AND PD.Loc=UCC.Loc
              )
         JOIN dbo.LOC LOC WITH (NOLOCK) ON  PD.LOC = LOC.LOC
         LEFT JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON  (
                  CLK.ListName='LOCCATEGRY'
              AND LOC.LocationCategory=CLK.Code
              )
         WHERE  LOC.LocationCategory NOT IN ('SHELVING','GOH')
         AND    WD.WaveKey = @c_WaveKey
         AND    ISNULL(UCC.UCCNo ,'') = '')
   BEGIN
         DECLARE CUR_NonUCCLoc CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT  DISTINCT PD.LOC
         FROM  dbo.WAVEDETAIL WD WITH (NOLOCK)
         JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON  (OD.OrderKey=WD.OrderKey)
         JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON  (
                  OD.StorerKey=PD.StorerKey
              AND OD.OrderKey=PD.OrderKey
        AND OD.OrderLineNumber=PD.OrderLineNumber)
         LEFT JOIN dbo.UCC UCC WITH (NOLOCK) ON  (
                  PD.StorerKey=UCC.StorerKey
              AND PD.SKU=UCC.SKU
              AND PD.Loc=UCC.Loc
              AND UCC.Status < '6'
              )
         JOIN dbo.LOC LOC WITH (NOLOCK) ON  PD.LOC = LOC.LOC
         LEFT JOIN dbo.CODELKUP CLK WITH (NOLOCK) ON  (
                  CLK.ListName='LOCCATEGRY'
              AND LOC.LocationCategory=CLK.Code
              )
         WHERE  LOC.LocationCategory NOT IN ('SHELVING','GOH')
         AND    WD.WaveKey = @c_WaveKey
         AND    ISNULL(UCC.UCCNo ,'') = ''

         OPEN CUR_NonUCCLoc
         FETCH NEXT FROM CUR_NonUCCLoc INTO @c_NonUCCLocation
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            IF ISNULL(RTRIM(@c_errmsg),'') = ''
            BEGIN
               SET @c_errmsg = 'UCC NOT Found In Allocated Location: ' + @c_NonUCCLocation

               INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------')
               INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'UCC NOT Found In Allocated Location')
               INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-----------------------------------')
               INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NCHAR(10), 'Location') )
               INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 10) )
            END
            ELSE
            BEGIN
               IF LEN(@c_ErrMsg) <= 240
                  SET @c_ErrMsg = @c_ErrMsg + ',' + @c_NonUCCLocation
            END

            INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES
            (@c_WaveKey, CONVERT(NCHAR(10), @c_NonUCCLocation))

            FETCH NEXT FROM CUR_NonUCCLoc INTO @c_NonUCCLocation
         END
         CLOSE CUR_NonUCCLoc
         DEALLOCATE CUR_NonUCCLoc

      SET @n_continue = 3
      SET @n_Err = 31311
      --GOTO RETURN_SP
   END

   IF EXISTS( SELECT 1 FROM ORDERDETAIL  o WITH (NOLOCK)
              JOIN   WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = O.OrderKey
              WHERE  W.WaveKey = @c_WaveKey
              GROUP BY  o.ConsoOrderKey, o.ConsoOrderLineNo
              HAVING COUNT(DISTINCT o.OrderKey+o.OrderLineNumber) > 1)
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 31312
      SELECT @c_errmsg=CONVERT(NVARCHAR(5),@n_err)+': Found Duplicate Conso Order LineNo. (ispWAVRL01)'
      --GOTO RETURN_SP
   END

   IF EXISTS( SELECT 1 FROM ORDERDETAIL  o WITH (NOLOCK)
              JOIN   WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = O.OrderKey
              JOIN   SKU WITH (NOLOCK) ON SKU.Sku = o.Sku AND SKU.StorerKey = o.StorerKey
              WHERE  W.WaveKey = @c_WaveKey
              AND    (SKU.DESCR = '' OR SKU.DESCR IS NULL))
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 31313
      SELECT @c_errmsg=CONVERT(NVARCHAR(5),@n_err)+': Found SKU With Blank Description. (ispWAVRL01)'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '      Found SKU With Blank Description')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '-------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NCHAR(20), 'SKU'))
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 20) )
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)
      SELECT DISTINCT
         @c_WaveKey,
         SKU.SKU
      FROM ORDERDETAIL  o WITH (NOLOCK)
      JOIN WAVEDETAIL w WITH (NOLOCK) ON w.OrderKey = O.OrderKey
      JOIN SKU WITH (NOLOCK) ON SKU.Sku = o.Sku AND SKU.StorerKey = o.StorerKey
      WHERE W.WaveKey = @c_WaveKey
      AND  (SKU.DESCR = '' OR SKU.DESCR IS NULL)

      --GOTO RETURN_SP
   END

   EXEC [dbo].[ispReddWerkWaveValidation]
   @c_WaveKey,
   @b_Success  OUTPUT,
   @n_Err      OUTPUT,
   @c_ErrMsg   OUTPUT
   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3
      --GOTO RETURN_SP
   END

   DECLARE @nBlk_ServiceType  INT,
           @nBlk_Street       INT,
           @nBlk_City         INT,
           @nBlk_PostCode     INT,
           @nBlk_Country      INT,
           @nBlk_ReceiverName INT,
           @nBlk_ReceiverPhone INT

   SELECT  @nBlk_ServiceType  =0,
           @nBlk_Street       =0,
           @nBlk_City         =0,
           @nBlk_PostCode     =0,
           @nBlk_Country      =0,
           @nBlk_ReceiverName =0,
           @nBlk_ReceiverPhone =0

   SELECT @nBlk_ServiceType   = SUM(CASE WHEN ISNULL(OH.M_Phone2,'') = '' THEN 1 ELSE 0 END),
          @nBlk_Street        = SUM(CASE WHEN ISNULL(OH.C_Address1,'') = '' THEN 1 ELSE 0 END),
          @nBlk_City          = SUM(CASE WHEN ISNULL(OH.C_City,'') = '' THEN 1 ELSE 0 END),
          @nBlk_PostCode      = SUM(CASE WHEN ISNULL(OH.C_Zip,'') = '' THEN 1 ELSE 0 END),
          @nBlk_Country       = SUM(CASE WHEN ISNULL(OH.C_Country,'') = '' THEN 1 ELSE 0 END),
          @nBlk_ReceiverName  = SUM(CASE WHEN ISNULL(OH.C_Contact1,'') = '' THEN 1 ELSE 0 END),
          @nBlk_ReceiverPhone = SUM(CASE WHEN ISNULL(OH.C_Phone1,'') = '' THEN 1 ELSE 0 END)
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)
   INNER JOIN StorerConfig sc WITH (NOLOCK) ON
       (sc.StorerKey = OH.StorerKey AND sc.ConfigKey = 'AgileProcess' AND SC.SValue ='1')
   WHERE WD.Wavekey = @c_WaveKey
   AND OH.SpecialHandling IN ('X','U','D')

   IF @nBlk_ServiceType   >0 OR
      @nBlk_Street        >0 OR
      @nBlk_City          >0 OR
      @nBlk_PostCode      >0 OR
      @nBlk_Country       >0 OR
      @nBlk_ReceiverName  >0 OR
      @nBlk_ReceiverPhone >0
   BEGIN
      SET @n_continue = 3
      SET @n_Err = 31301
      SET @c_ErrMsg = 'Found Insufficient data in Order Addresses for Agile Process. ' + @c_WaveKey +
                      CASE WHEN @nBlk_ServiceType > 0
                           THEN CAST(@nBlk_ServiceType AS NVARCHAR(5)) + ' Orders with Blank Service Type. '
                           ELSE '' END +
                      CASE WHEN @nBlk_Street > 0
                           THEN CAST(@nBlk_Street AS NVARCHAR(5)) + ' Orders with Blank Street. '
                           ELSE '' END +
                      CASE WHEN @nBlk_City > 0
                           THEN CAST(@nBlk_City AS NVARCHAR(5)) + ' Orders with Blank City. '
                           ELSE '' END +
                      CASE WHEN @nBlk_PostCode > 0
                           THEN CAST(@nBlk_PostCode AS NVARCHAR(5)) + ' Orders with Blank Post Code. '
                           ELSE '' END +
                      CASE WHEN @nBlk_Country > 0
                  THEN CAST(@nBlk_Country AS NVARCHAR(5)) + ' Orders with Blank Country Code. '
                           ELSE '' END +
                      CASE WHEN @nBlk_ReceiverName > 0
                           THEN CAST(@nBlk_ReceiverName AS NVARCHAR(5)) + ' Orders with Blank Contact. '
                           ELSE '' END +
                      CASE WHEN @nBlk_ReceiverPhone > 0
                           THEN CAST(@nBlk_ReceiverPhone AS NVARCHAR(5)) + ' Orders with Blank Phone. '
                           ELSE '' END +
                      '. (ispWAVRL01)'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '------------------------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Found Insufficient data in Order Addresses for Agile Process')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '------------------------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NCHAR(10), 'Order#') + ' ' +
                                                                             CONVERT(NCHAR(10), 'Service') + ' ' +
                                                                             CONVERT(NCHAR(10), 'Zip Cd') + ' ' +
                                                                             CONVERT(NCHAR(10), 'Country') + ' ' +
                                                                             CONVERT(NCHAR(10), 'Name') + ' ' +
                                                                             CONVERT(NCHAR(10), 'Phone'))
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, REPLICATE('-', 10) + ' ' +
                                                                             REPLICATE('-', 10) + ' ' +
                                                                             REPLICATE('-', 10) + ' ' +
                                                                             REPLICATE('-', 10) + ' ' +
                                                                             REPLICATE('-', 10) + ' ' +
                                                                             REPLICATE('-', 10) )
      INSERT INTO WaveRelErrorReport (WaveKey, LineText)
      SELECT WD.Wavekey,
             CONVERT(NCHAR(10), OH.OrderKey) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.M_Phone2,'')   = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_Address1,'') = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_City,'')     = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_Zip,'')      = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_Country,'')  = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_Contact1,'') = '' THEN 'BLANK' ELSE '' END)) + ' ' +
             CONVERT(NCHAR(10),(CASE WHEN ISNULL(OH.C_Phone1,'')   = '' THEN 'BLANK' ELSE '' END)) + ' '
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)
      INNER JOIN StorerConfig sc WITH (NOLOCK) ON
          (sc.StorerKey = OH.StorerKey AND sc.ConfigKey = 'AgileProcess' AND SC.SValue ='1')
      WHERE WD.Wavekey = @c_WaveKey
      AND OH.SpecialHandling IN ('X','U','D')

      --GOTO RETURN_SP
   END


   --11-JAN-2012 YTWan -Prevention on not allocated orders in the wave from sending to Reddwerks - START
   IF EXISTS (SELECT 1
              FROM WAVEDETAIL WD WITH (NOLOCK)
              JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)
              WHERE WD.Wavekey = @c_WaveKey
              AND OH.Status < '1')
   BEGIN
      SET @n_continue = 3
      SET @n_Err = 31302
      SEt @c_ErrMsg = 'Non allocated orders exists. Please remove from Wave: ' + @c_WaveKey
                    + '. (ispWAVRL01)'

      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, 'Non allocated orders exists. Please remove from Wave')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, '----------------------------------------------------')
      INSERT INTO WaveRelErrorReport (WaveKey, LineText) VALUES (@c_WaveKey, CONVERT(NCHAR(10), 'Order#'))

      INSERT INTO WaveRelErrorReport (WaveKey, LineText)
      SELECT WD.Wavekey,
             WD.OrderKey
      FROM WAVEDETAIL WD WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (OH.Orderkey = WD.Orderkey)
      WHERE WD.Wavekey = @c_WaveKey
      AND OH.Status < '1'

      --GOTO RETURN_SP
   END
   IF EXISTS(SELECT 1 FROM WaveRelErrorReport WITH (NOLOCK)
             WHERE WaveKey = @c_WaveKey AND (@n_continue NOT IN (1,2)) )
   BEGIN
      SET @n_continue = 3
      SET @b_Success = 0
      GOTO RETURN_SP
   END

--(Wan01) - START
   IF @b_ValidateOnly = 1
   BEGIN
      GOTO RETURN_SP
   END
   --(Wan01) - END

   --NJOW01
   EXEC [dbo].[isp_WaveAutoCreateMBOL]
   @c_WaveKey,
   @b_Success  OUTPUT,
   @n_Err      OUTPUT,
   @c_ErrMsg2   OUTPUT
   IF @b_Success <> 1
   BEGIN
      SET @n_continue = 3
      GOTO RETURN_SP
   END

   -- Delete PreAllocatePickDetail
   IF EXISTS(SELECT 1
             FROM PreAllocatePickDetail papd WITH (NOLOCK)
             JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = papd.OrderKey
             WHERE WD.WaveKey = @c_WaveKey
               AND papd.Qty > 0)
   BEGIN
      DELETE papd
      FROM PreAllocatePickDetail papd
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON WD.OrderKey = papd.OrderKey
      WHERE WD.WaveKey = @c_WaveKey
        AND papd.Qty > 0
      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 31314
         SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                    + ': Fail Deleting Pre-Allocation Records ' + @c_WaveKey
                    + '. (ispWAVRL01)'
         GOTO RETURN_SP
      END
   END


   -- (james01)
   -- Clear PickDetail.CaseID to prevent manual allocation from show pick which will create base
   -- caseid. WCS Carton Close msg will fail if PickDetail.CaseID <> ''
   IF EXISTS (SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK)
              JOIN  dbo.WaveDetail WD WITH (NOLOCK) ON PD.OrderKey = WD.OrderKey
              WHERE WD.Wavekey = @c_WaveKey
              AND PD.Status = '0'
              AND PD.CaseID <> '')
   BEGIN
      UPDATE PD with (ROWLOCK) SET CASEID = '', TrafficCop = NULL
      FROM dbo.PickDetail PD
      JOIN dbo.WaveDetail WD ON PD.OrderKey = WD.OrderKey
      WHERE WD.Wavekey = @c_WaveKey
      AND PD.Status = '0'
      AND PD.CaseID <> ''

      IF @@ERROR <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 31310
         SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                    + ': Error Updating PickDetail.CaseID = '' for Wave ' + @c_WaveKey
                    + '. (ispWAVRL01)'
         GOTO RETURN_SP
      END
   END

   DECLARE CUR_STR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                                         --(Wan02)
   --SELECT @c_Storerkey = MAX(ORDERS.Storerkey)                                                   --(Wan02)
   SELECT DISTINCT ORDERS.Storerkey                                                                --(Wan02)
   FROM WAVEDETAIL WITH (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE WAVEDETAIL.Wavekey = @c_WaveKey

   OPEN CUR_STR                                                                                    --(Wan02)

   FETCH NEXT FROM CUR_STR INTO @c_Storerkey                                                       --(Wan02)

   WHILE @@FETCH_STATUS <> -1                                                                      --(Wan02)
   BEGIN                                                                                           --(Wan02)
          EXECUTE dbo.nspGetRight NULL                 -- facility
                               ,  @c_Storerkey         -- Storerkey
                               ,  NULL                 -- Sku
                               ,  @c_Configkey         -- Configkey
                               ,  @b_success      OUTPUT
                               ,  @c_SValue       OUTPUT
                               ,  @n_err          OUTPUT
                               ,  @c_errmsg       OUTPUT


          IF @b_success <> 1
          BEGIN
             SET @n_continue = 3
             SET @n_Err = 31303
             SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                           + ': Error Getting StorerCongfig for Storer: ' + @c_Storerkey
                           + '. (ispWAVRL01)'
             GOTO RETURN_SP
          END

         IF @c_SValue <> '1'
         BEGIN
            --(Wan02) - START
            --SET @n_continue = 3
            --SET @n_Err = 31304
            --SET @c_ErrMsg = 'StorerCongfig: ' + RTRIM(@c_Configkey) + ' not setup for Storer: ' + RTRIM(@c_Storerkey)
            --              + '. (ispWAVRL01)'
            --GOTO RETURN_SP
            GOTO NEXT_STORER
            --(Wan02) - END
         END
   ELSE
   BEGIN

      IF EXISTS ( SELECT 1 FROM TransmitLog3 WITH (NOLOCK)
                  WHERE TableName = @c_Configkey
                  AND Key1 = @c_WaveKey
                  AND Key3 = @c_Storerkey)
      BEGIN
         SET @c_Configkey = 'WAVEUPDLOG'

         -- If config 'WAVEUPDLOG' not turned on then no more re-release of wave    (james02)
         EXECUTE dbo.nspGetRight NULL                 -- facility
                              ,  @c_Storerkey         -- Storerkey
                              ,  NULL                 -- Sku
                              ,  @c_Configkey         -- Configkey
                              ,  @b_success      OUTPUT
                              ,  @c_SValue       OUTPUT
                              ,  @n_err          OUTPUT
                              ,  @c_errmsg       OUTPUT


          IF @c_SValue <> '1'
          BEGIN
             --(Wan02) - START
             SET @c_ErrMsg = 'Wave released. Cannot Re-send.'
             --GOTO RETURN_SP
             GOTO NEXT_STORER
             --(Wan02) - END
          END

         IF EXISTS (SELECT 1 FROM PickDetail_Log WITH (NOLOCK) WHERE WaveKey = @c_WaveKey AND Status = '0')
         BEGIN
            SET @c_ErrMsg = 'Re-sent completed.'
            IF EXISTS (SELECT 1 FROM TransmitLog3 WITH (NOLOCK)
                       WHERE TableName = @c_Configkey AND Key1 = @c_WaveKey AND Key3 = @c_Storerkey AND TransmitFlag = '0')
            BEGIN
                --(Wan02) - START
                --GOTO RETURN_SP
                GOTO NEXT_STORER
                --(Wan02) - END
            END
         END
         ELSE
         BEGIN
             --(Wan02) - START
             SET @c_ErrMsg = 'Nothing To Re-send.'
             --GOTO RETURN_SP
             GOTO NEXT_STORER
             --(Wan02) - END
         END
      END

      SET @b_success = 1
      EXECUTE nspg_getkey 'TransmitlogKey3'
                        , 10
                        , @c_TransmitlogKey  OUTPUT
                        , @b_success         OUTPUT
                        , @n_err             OUTPUT
                        , @c_errmsg                   --Not get errmsg from nspg_getkey for this function

      IF NOT @b_success = 1
      BEGIN
         SET @n_continue = 3
         SET @n_Err = 31305
         SET @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                       + ': Unable to Obtain transmitlogkey (ispWAVRL01)'
         GOTO RETURN_SP
      END
      ELSE
      BEGIN
         INSERT INTO Transmitlog3 (Transmitlogkey, Tablename, Key1, Key2, Key3, TransmitFlag)
         VALUES (@c_TransmitlogKey, @c_Configkey, @c_WaveKey, '', @c_Storerkey, '0')

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 31306
            SET @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                          + ': Error Insert Into Tablename (' + RTRIM(@c_Configkey) + ') record to Transmitlog3'
                          + ' (ispWAVRL01)'
            GOTO RETURN_SP
         END
      END

      -- Start (ChewKP01)

      SELECT @b_success = 0

      EXECUTE dbo.nspGetRight  NULL,
               @c_StorerKey,        -- Storer
               '',                  -- Sku
               'PICKRESLOG',        -- ConfigKey
               @b_success              OUTPUT,
               @c_authority_pickreslog OUTPUT,
               @n_Err                  OUTPUT,
               @c_ErrMsg               OUTPUT

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_ErrMsg = 31307
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0))
                          + ': Retrieve of Right (PICKRESLOG) Failed ( '
                          + ' (ispWAVRL01)'
      END

      IF @c_authority_pickreslog = '1'
      BEGIN

          DECLARE CursorWaveDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT WAVEDETAIL.OrderKey FROM WaveDetail WITH (NOLOCK)                               --(Wan02)
          JOIN ORDERS (NOLOCK) ON (WAVEDETAIL.Orderkey = ORDERS.Orderkey)                        --(Wan02)
          WHERE WAVEDETAIL.Wavekey = @c_WaveKey                                                  --(Wan02)
          AND   ORDERS.Storerkey = @c_Storerkey                                                  --(Wan02)

          OPEN CursorWaveDetail

          FETCH NEXT FROM CursorWaveDetail INTO @c_OrderKey

          WHILE @@FETCH_STATUS <> -1
          BEGIN

             EXEC dbo.ispGenTransmitLog3 'PICKRESLOG', @c_OrderKey, '', @c_StorerKey, ''
                                 , @b_success OUTPUT
                                 , @n_Err OUTPUT
                                 , @c_ErrMsg OUTPUT

             IF @b_success <> 1
             BEGIN
                SELECT @n_continue = 3
             END

            FETCH NEXT FROM CursorWaveDetail INTO @c_OrderKey
          END
          CLOSE CursorWaveDetail
          DEALLOCATE CursorWaveDetail
      END
      -- End (ChewKP01)
         --(Wan02) - START
         IF RTRIM(@c_ErrMsg3) = ''
         BEGIN
            SET @c_ErrMsg3 = 'Release Completed for storer: ' + @c_StorerKey
         END
         ELSE
         BEGIN
            SET @c_ErrMsg3 =  @c_ErrMsg3 + ', ' + @c_StorerKey
         END
         --(Wan02) - END
      END
      NEXT_STORER:                                                                                 --(Wan02)
      FETCH NEXT FROM CUR_STR INTO @c_Storerkey                                                    --(Wan02)
   END                                                                                             --(Wan02)
   CLOSE CUR_STR                                                                                   --(Wan02)
   DEALLOCATE CUR_STR                                                                              --(Wan02)

   --(Wan02) - START
   IF @c_ErrMsg3 = ''
   BEGIN
      SET @c_ErrMsg = 'Nothing to released.'
   END
   ELSE
   BEGIN
      SET @c_ErrMsg = @c_ErrMsg3 + '.'
   END
   --(Wan02) - END
   -- (ChewKP02)
   /***************************************************/
   /* Create PickHeader For All ConsoOrder            */
   /***************************************************/

   DECLARE CUR_PH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

   SELECT DISTINCT OD.ConsoOrderKey
   FROM WAVEDETAIL WD WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OD.Orderkey = WD.Orderkey)
   WHERE WD.Wavekey = @c_WaveKey

   OPEN CUR_PH

   FETCH NEXT FROM CUR_PH INTO @c_ConsoOrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @c_PickSlipNo = ''

      SELECT @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE ConsoOrderKey = @c_ConsoOrderKey




      IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''
      BEGIN

         SET @b_Success = 0

         EXECUTE nspg_GetKey
            'PICKSLIP',
            9,
            @c_PickSlipNo     OUTPUT,
            @b_Success        OUTPUT,
            @n_Err            OUTPUT,
            @c_ErrMsg         OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 31308
            SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                          + ': Error Getting PickSlipNo'
                          + '. (ispWAVRL01)'
            GOTO RETURN_SP
         END

         -- (ChewKP03)
         INSERT INTO TRACEINFO (TraceName , TimeIn, Step1, Step2, Step3, Col1, Col2, col3)
         VALUES ( 'ispWAVRL01', GETDATE(), 'PickslipNo', 'ConsoKey', 'Continue', @c_PickSlipNo, @c_ConsoOrderKey, @n_Continue)

         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            SET @c_PickSlipNo = 'P' + @c_PickSlipNo

            INSERT INTO dbo.PickHeader (PickHeaderKey,  ExternOrderKey, Orderkey, Zone, ConsigneeKey, ConsoOrderKey)
            VALUES (@c_PickSlipNo, '', '', 'LP', '',@c_ConsoOrderKey)

            SET @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err = 31309
               SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                             + ': Error Creating PickHeader For ConsoOrderKey:' + @c_ConsoOrderKey
                             + '. (ispWAVRL01)'
               GOTO RETURN_SP
            END


         END -- @n_Continue = 1 or @n_Continue = 2


      END -- IF ISNULL(RTRIM(@c_PickSlipNo),'') = ''

      FETCH NEXT FROM CUR_PH INTO @c_ConsoOrderKey

   END
   CLOSE CUR_PH
   DEALLOCATE CUR_PH

   /***************************************************/
   /* Calculate Residual Move for Last Carton         */
   /* Added By Shong on 25th Sep 2012                 */
   /***************************************************/
   DECLARE @n_AllocatedQty      INT,
           @n_UCCQty            INT,
           @n_PreMoveQty       INT,
           @n_LooseQty          INT,
           @n_AvailableQty      INT,
           @c_SKU               NVARCHAR(20),
           @c_LOC               NVARCHAR(10),
           @c_PackKey           NVARCHAR(10),
           @c_UOM               NVARCHAR(10),
           @c_FromLot           NVARCHAR(10),
           @c_FromID            NVARCHAR(18),
           @n_FromQty           INT,
           @n_FromQtyToTake     INT,
           @c_ToLoc             NVARCHAR(10)

   SET @c_ToLoc = ''
   SELECT @c_ToLoc   = Short
   FROM   dbo.CodeLkUp WITH (NOLOCK)
   WHERE  ListName   = 'WCSROUTE'
   AND    Code       = 'CASE'
   IF ISNULL(RTRIM(@c_ToLoc),'') = ''
   BEGIN
      SET @n_continue = 3
      SET @n_Err = 31312
      SEt @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(10), @n_Err)
                    + ': WCS Route Location Not Setup in Code Lookup Table: ListName = WCSROUTE and Code = CASE'
                    + '. (ispWAVRL01)'
      GOTO RETURN_SP
   END

   DECLARE CUR_RESIDUAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PD.StorerKey, PD.SKU, SUM(Qty) AS AllocatedQty, PD.LOC
      FROM  dbo.WAVEDETAIL WD WITH (NOLOCK)
      JOIN dbo.PICKDETAIL PD WITH (NOLOCK) ON  (WD.OrderKey=PD.OrderKey)
      JOIN dbo.LOC LOC WITH (NOLOCK) ON  PD.LOC = LOC.LOC
           AND LOC.LocationCategory NOT IN ('SHELVING','GOH')
      WHERE WD.WaveKey = @c_WaveKey
      GROUP BY PD.StorerKey, PD.SKU, PD.LOC

   OPEN CUR_RESIDUAL

   FETCH NEXT FROM CUR_RESIDUAL INTO @c_Storerkey, @c_SKU, @n_AllocatedQty, @c_LOC
   WHILE @@FETCH_STATUS <> -1
   BEGIN
--    SELECT @c_Storerkey '@c_Storerkey', @c_SKU '@c_SKU', @n_AllocatedQty '@n_AllocatedQty', @c_LOC '@c_LOC'

    IF EXISTS(SELECT 1 FROM WCS_ResidualMoveLog WITH (NOLOCK)
              WHERE WaveKey = @c_WaveKey AND
                    Loc     = @c_LOC AND
                    StorerKey = @c_Storerkey AND
                    SKU       = @c_SKU)
      BEGIN
         -- Residual already done, do not move again
         GOTO FETCH_NEXT_RESIDUAL
      END

      SET @n_UCCQty = 0

      SET @n_UCCQty = dbo.fnc_GetLocUccPackSize(@c_StorerKey, @c_SKU, @c_LOC)

      IF @n_UCCQty <= 0
      BEGIN
         -- No UCC Found, do nothing
         GOTO FETCH_NEXT_RESIDUAL
      END

      SET @n_AvailableQty = 0
      SELECT @n_AvailableQty = SUM(Qty) - SUM(QtyAllocated) - SUM(QtyPicked)
      FROM SKUxLOC WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND LOC = @c_LOC


      IF @n_AvailableQty > @n_UCCQty
      BEGIN
         -- Not last Carton, Do nothing
         GOTO FETCH_NEXT_RESIDUAL
      END


      SET @n_PreMoveQty = @n_AvailableQty

      IF @n_PreMoveQty > 0
      BEGIN
         SELECT @c_PackKey = SKU.PackKey
              , @c_UOM     = PACK.PACKUOM3
         FROM   dbo.SKU WITH (NOLOCK)
         JOIN   dbo.PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PackKey
         WHERE  StorerKey = @c_StorerKey
         AND    SKU = @c_SKU

         IF ISNULL(RTRIM(@c_PackKey),'') = ''
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 31310
            SET @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                          + ': Packkey not found, SKU:' + @c_SKU
                          + '. (ispWAVRL01)'
            GOTO RETURN_SP
         END

         SET @n_AvailableQty = 0

         SELECT @n_AvailableQty = SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
         FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE  LLI.StorerKey = @c_StorerKey
         AND    LLI.SKU       = @c_SKU
         AND    LLI.LOC       = @c_LOC
         AND    QTY - QtyPicked - QtyAllocated - QtyReplen > 0

         IF @n_AvailableQty < @n_PreMoveQty
         BEGIN
            SET @n_continue = 3
            SET @n_Err = 31311
            SET @c_ErrMsg = 'NSQL' +  CONVERT(VARCHAR(250), @n_Err)
                          + ': Insufficient FromQty to move, SKU:' + @c_SKU + ' Loc:' + @c_LOC
                          + '. (ispWAVRL01)'
            GOTO RETURN_SP
         END

         DECLARE CUR_LOTxLOCxID_MOVE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LOT,
                ID,
                LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
         FROM   dbo.LOTxLOCxID LLI WITH (NOLOCK)
         WHERE  LLI.StorerKey = @c_StorerKey
         AND    LLI.SKU       = @c_SKU
         AND    LLI.LOC       = @c_Loc
         AND    (LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
         ORDER BY LLI.Lot

         OPEN CUR_LOTxLOCxID_MOVE

         FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_FromQtyToTake = 0

            IF @n_FromQty >= @n_PreMoveQty
            BEGIN
               SET @n_FromQtyToTake = @n_PreMoveQty
            END
            ELSE --IF @n_FromQty < @n_PreMoveQty
            BEGIN
               SET @n_FromQtyToTake = @n_FromQty
            END

            IF @n_FromQtyToTake > 0
            BEGIN
               EXECUTE nspItrnAddMove
                  @n_ItrnSysId      = NULL,
                  @c_itrnkey        = NULL,
                  @c_Storerkey      = @c_StorerKey,
                  @c_SKU            = @c_SKU,
                  @c_Lot            = @c_FromLot,
                  @c_FromLoc        = @c_Loc,
                  @c_FromID         = @c_FromID,
                  @c_ToLoc          = @c_ToLoc,
                  @c_ToID           = '',
                  @c_Status         = '',
                  @c_Lottable01     = '',
                  @c_Lottable02     = '',
                  @c_Lottable03     = '',
                  @d_Lottable04     = NULL,
                  @d_Lottable05     = NULL,
						@c_Lottable06     = '',				--(CS01)
                  @c_Lottable07     = '',				--(CS01)
                  @c_Lottable08     = '',				--(CS01)
						@c_Lottable09     = '',				--(CS01)
                  @c_Lottable10     = '',				--(CS01)
                  @c_Lottable11     = '',				--(CS01)
						@c_Lottable12     = '',				--(CS01)
						@d_Lottable13     = NULL,			--(CS01)
                  @d_Lottable14     = NULL,			--(CS01)
                  @d_Lottable15     = NULL,			--(CS01)
                  @n_casecnt        = 0,
                  @n_innerpack      = 0,
                  @n_Qty            = @n_FromQtyToTake,
                  @n_Pallet         = 0,
                  @f_Cube           = 0,
                  @f_GrossWgt       = 0,
                  @f_NetWgt         = 0,
                  @f_OtherUnit1     = 0,
                  @f_OtherUnit2     = 0,
                  @c_SourceKey      = @c_WaveKey,
                  @c_SourceType     = 'ispWAVRL01',
                  @c_PackKey        = @c_PackKey,
                  @c_UOM            = @c_UOM,
                  @b_UOMCalc        = 1,
                  @d_EffectiveDate  = NULL,
                  @b_Success        = @b_Success   OUTPUT,
                  @n_err            = @n_Err       OUTPUT,
                  @c_errmsg         = @c_Errmsg    OUTPUT

               IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err     = @n_Err
                  SET @c_ErrMsg  = @c_ErrMsg
                  GOTO RETURN_SP
               END
               ELSE
               BEGIN
                  IF NOT EXISTS(SELECT 1 FROM WCS_ResidualMoveLog WITH (NOLOCK)
                          WHERE WaveKey = @c_WaveKey AND
                          Loc     = @c_LOC AND
                          StorerKey = @c_Storerkey AND
                          SKU       = @c_SKU)
                  BEGIN
                      INSERT INTO WCS_ResidualMoveLog
                      (WaveKey,       Loc,          StorerKey,
                       SKU,           PreMoveQty,  ActualMoveQty,
                       AddDate,       EditDate) VALUES
                      (@c_WaveKey,   @c_LOC,            @c_Storerkey,
                       @c_SKU,       @n_FromQtyToTake,  0,
                       GETDATE(),    GETDATE())
                  END
                  ELSE
                  BEGIN
                     UPDATE WCS_ResidualMoveLog
                         SET PreMoveQty = PreMoveQty + @n_FromQtyToTake
                     WHERE WaveKey = @c_WaveKey AND
                           Loc     = @c_LOC AND
                           StorerKey = @c_Storerkey AND
                           SKU       = @c_SKU
                  END
               END

               SET @n_PreMoveQty = @n_PreMoveQty - @n_FromQtyToTake

               IF @n_PreMoveQty = 0
 BEGIN
                  BREAK
               END
            END -- IF @n_FromQtyToTake > 0

            FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @c_FromLot, @c_FromID, @n_FromQty
         END
         CLOSE CUR_LOTxLOCxID_MOVE
         DEALLOCATE CUR_LOTxLOCxID_MOVE
      END --IF @n_PreMoveQty > 0

FETCH_NEXT_RESIDUAL:
      FETCH NEXT FROM CUR_RESIDUAL INTO @c_Storerkey, @c_SKU, @n_AllocatedQty, @c_LOC
   END -- Fetch CUR_RESIDUAL
   CLOSE CUR_RESIDUAL
   DEALLOCATE CUR_RESIDUAL
   /***************************************************/
   /* Perform MOVE End                                */
   /***************************************************/


END -- Procedure

RETURN_SP:

SET @c_errmsg = RTRIM(@c_errmsg) + ' ' + RTRIM(LTRIM(@c_errmsg2))

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      ROLLBACK TRAN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
   END
   execute nsp_logerror @n_err, @c_errmsg, 'ispWAVRL01'
   --RAISERROR @n_err @c_errmsg
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_StartTranCnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO