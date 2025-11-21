SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: isp_InsertMBOLDetail                                   */
/* Creation Date:                                                           */
/* Copyright: IDS                                                           */
/* Written by:                                                              */
/*                                                                          */
/* Purpose:                                                                 */
/*                                                                          */
/* Called By:                                                               */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 5.4                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author   Ver.  Purposes                                     */
/* 19-Aug-2005  June     1.0   SOS39592, SOS39659, SOS39660                 */
/*                                      - IDSPH ULP v54 bug fix             */
/* 30-Mac-2011  AQSKC    1.0   SOS209175 - Populate total carton from       */
/*                             packing info to mboldetail (Kc01)            */
/* 25-May-2011  Ung      1.1   a) SOS216105 Configurable SP to calc         */
/*                             carton, cube and weight                      */
/* 20-Dec-2011  SHONG    1.2   Adding New Calculation for LCI Total Ctns    */  
/*                             Calculation  (SHONG01)                       */
/*                             b) SOS209175 Remove                          */
/* 15-Feb-2012  wtshong  1.3   initial Null value                           */
/* 14-Mar-2012  KHLim01  1.4   Update EditDate                              */    
/* 23-Apr-2012  NJOW01   1.5   241032-Calculation by coefficient            */   
/* 18-Jun-2012  NJOW02   1.6   Fix coefficient calculation                  */
/* 23-Sep-2013  NJOW03   1.7   2900014-SConfig to update MBOL Departure     */
/*                             date from order delivery date.               */
/* 14-Apr-2015  TLTING   1.8   Deadlock Tune                                */
/* 07-Dec-2015  James    1.9   Bug fix (james01)                            */
/* 31-May-2016  CSCHONG  2.0   SOS#371052 change field logic (CS01)         */
/* 10-Aug-2016  CSCHONG  2.1   SOS#373477 Add Pre and post insert           */
/*                       2.2   mboldetail wrapper (CS02)                    */ 
/* 28-Jan-2019  TLTING01 2.3   enlarge externorderkey field length          */
/* 27-Nov-2019  WLChooi  2.4   WMS-11168 - Update Route from Voyage(WL01)   */
/* 29-Nov-2019  WLChooi  2.5   WMS-11169 - New Storerconfig -               */ 
/*                                        DefaultCarrierAgent (WL02)        */
/* 28-May-2020  NJOW04   2.6   WMS-13515 Move post                                     */
/****************************************************************************/
 
CREATE PROCEDURE [dbo].[isp_InsertMBOLDetail] 
   @cMBOLKey          NVARCHAR(10),
   @cFacility         NVARCHAR(5),            
   @cOrderKey         NVARCHAR(10),  
   @cLoadKey          NVARCHAR(10),        
   @nStdGrossWgt      float = 0 ,      
   @nStdCube          float = 0 ,         
   @cExternOrderKey   NVARCHAR(50) = '',    --tlting01
   @dOrderDate        datetime,
   @dDelivery_Date    datetime, 
   @cRoute            NVARCHAR(10) = '', 
   @b_Success         int = 1        OUTPUT, 
   @n_err             int = 0        OUTPUT,
   @c_errmsg          NVARCHAR(255) = '' OUTPUT   
AS
BEGIN -- main
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE   @n_continue           int                 
   ,         @n_starttcnt          int       -- Holds the current transaction count
   ,         @n_LineNo             int
   ,         @cMBOLLineNumber      NVARCHAR(5)
   ,         @c_authority          NVARCHAR(1)
   ,         @cMBOL_Facility       NVARCHAR(5)
   ,         @n_cnt                int 
   ,         @cCustomerName        NVARCHAR(45)
   ,         @cInvoiceNo           NVARCHAR(10) 
   ,         @nTotalCarton         int                --(KC01)
   ,         @c_Storerkey          NVARCHAR(15)        --(KC01)
   ,         @cCtnTyp1             NVARCHAR(10)        --SOS216105
   ,         @cCtnTyp2             NVARCHAR(10)        --SOS216105
   ,         @cCtnTyp3             NVARCHAR(10)        --SOS216105
   ,         @cCtnTyp4             NVARCHAR(10)        --SOS216105
   ,         @cCtnTyp5             NVARCHAR(10)        --SOS216105
   ,         @nCtnCnt1             int                --SOS216105
   ,         @nCtnCnt2             int                --SOS216105
   ,         @nCtnCnt3             int                --SOS216105
   ,         @nCtnCnt4             int                --SOS216105
   ,         @nCtnCnt5             int                --SOS216105
   ,         @nTotalCube           float              --SOS216105
   ,         @nTotalWeight         float              --SOS216105
   ,         @n_Coefficient_carton float  --NJOW01
   ,         @n_Coefficient_cube   float  --NJOW01
   ,         @n_Coefficient_weight float  --NJOW01
   ,         @c_GetAuthority       NVARCHAR(30) --WL02
   
   
   /*CS02 start*/
   DECLARE   @c_PreAddMBOLDETAILSP  NVARCHAR (10)      
   ,         @c_POSTAddMBOLDETAILSP NVARCHAR (10)      
   ,         @n_Err2                int                    
   ,         @c_MBDETLineNo         NVARCHAR(5)          
   ,         @c_ConfigKey           NVARCHAR(30)       
	 
   
   
   SELECT @b_success = 0, @n_continue = 1 
   
   --NJOW04
   SELECT @cCustomerName = ISNULL(c_Company, ''), 
          @cInvoiceNo    = ISNULL(InvoiceNo, ''),
          @c_Storerkey   = ISNULL(Storerkey, '')      --(Kc01)
   FROM   ORDERS (NOLOCK)
   WHERE  OrderKey = @cOrderKey   
   
   EXECUTE nspGetRight null, -- facility
            null,            -- Storerkey
            null,            -- Sku
            'SINGLEFACILITYLOAD',        -- Configkey
            @b_success    output,
            @c_authority  output, 
            @n_err        output,
            @c_errmsg     output

   IF @c_authority = '1' AND @b_success = 1
   BEGIN
      SELECT @cMBOL_Facility = ISNULL(Facility, '')
      FROM   MBOL (NOLOCK)
      WHERE  MBOLKey = @cMBOLKey 

      IF @cMBOL_Facility <> @cFacility
      BEGIN
         SELECT @n_continue=3
         SELECT @n_err=72800
         SELECT @c_errmsg='Facility Mis-match for Order ' + dbo.fnc_RTrim(@cOrderkey) + '.'
      END      
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS(SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE (OrderKey = '' OR OrderKey IS NULL) AND MBOLKey = @cMBOLKey )
      BEGIN
         BEGIN TRAN 

         DELETE FROM MBOLDETAIL WITH (ROWLOCK) 
         WHERE   (OrderKey = '' OR OrderKey IS NULL) 
         AND    MBOLKey = @cMBOLKey   

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Failed On Table MBOL Detail. (isp_InsertMBOLDetail)' 
            ROLLBACK TRAN 
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > 0
            BEGIN
               COMMIT TRAN 
            END
         END 
      END 
   END 

   SELECT @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN 

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN      
      IF  EXISTS ( SELECT 1 FROM ORDERDETAIL WITH (NOLOCK) 
                   WHERE OrderKey = @cOrderKey
                     AND   Loadkey = @cLoadKey -- SOS39592
                     AND   (MBOLKey = '' OR MBOLKey IS NULL) )
      BEGIN
      
         UPDATE ORDERDETAIL WITH (ROWLOCK) 
            SET MBOLKey = @cMBOLKey, TrafficCop = NULL, 
                LoadKey = CASE WHEN LoadKey = '' OR LoadKey IS NULL THEN @cLoadKey ELSE LoadKey END 
               ,EditDate = GETDATE() -- KHLim01
         WHERE OrderKey = @cOrderKey
           AND   Loadkey = @cLoadKey -- SOS39592
         AND   (MBOLKey = '' OR MBOLKey IS NULL)
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Order Detail. (isp_InsertMBOLDetail)' 
         END
      END
   END 

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF EXISTS (       SELECT 1 FROM ORDERS WITH (NOLOCK)  
                        WHERE OrderKey = @cOrderKey
                        AND   (MBOLKey = '' OR MBOLKey IS NULL) )
      BEGIN                         
         UPDATE ORDERS WITH (ROWLOCK)  
            SET MBOLKey = @cMBOLKey, 
                LoadKey = CASE WHEN LoadKey = '' OR LoadKey IS NULL THEN @cLoadKey ELSE LoadKey END, 
                TrafficCop = NULL
               ,EditDate = GETDATE() -- KHLim01
         WHERE OrderKey = @cOrderKey
         AND   (MBOLKey = '' OR MBOLKey IS NULL)
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table Orders. (isp_InsertMBOLDetail)' 
         END
      END
   END 
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      -- SOS39660 & SOS39659 - add in Loadkey
      IF NOT EXISTS(SELECT 1 FROM MBOLDETAIL (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey AND Loadkey = @cLoadkey)
      BEGIN 
         SELECT @cMBOLLineNumber = RIGHT('0000' + dbo.fnc_RTrim(CAST(ISNULL(CAST(MAX(MBOLLineNumber) as int), 0) + 1 as NVARCHAR(5))), 5)
         FROM   MBOLDETAIL (NOLOCK)
         WHERE  MBOLKey = @cMBOLKey
            
         --(CS02) - START 
         IF @n_continue = 1 OR @n_continue = 2
         BEGIN
            SET @b_Success = 0
            SET @c_PreAddMBOLDETAILSP = ''
            EXEC nspGetRight  
                  @c_Facility  = @cFacility
                , @c_StorerKey = @c_StorerKey 
                , @c_sku       = NULL
                , @c_ConfigKey = 'PreAddMBOLDETAILSP'  
                , @b_Success   = @b_Success                  OUTPUT  
                , @c_authority = @c_PreAddMBOLDETAILSP        OUTPUT   
                , @n_err       = @n_err                      OUTPUT   
                , @c_errmsg    = @c_errmsg                   OUTPUT  
         
            IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PreAddMBOLDETAILSP AND TYPE = 'P')
            BEGIN
               SET @b_Success = 0  
               EXECUTE dbo.ispPreAddMBOLDETAILWrapper 
                       @c_mbolkey           = @cMBOLKey
                     , @c_orderkey          = @cOrderKey
                     , @c_loadkey           = @cLoadKey              
                     , @c_PreAddMBOLDETAILSP= @c_PreAddMBOLDETAILSP
                     , @c_MbolDetailLineNumber = @cMBOLLineNumber 
                     , @b_Success = @b_Success     OUTPUT  
                     , @n_Err     = @n_err         OUTPUT   
                     , @c_ErrMsg  = @c_errmsg      OUTPUT  
                     --, @b_debug   = 0 
         
               IF @n_err <> 0  
               BEGIN 
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL Detail. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
                 -- GOTO RollbackTran
               END 
            END 
         END
         --(CS02) - End

         -- SOS216105 start. Configurable SP to calc carton, cube and weight
         DECLARE @cSValue NVARCHAR( 10)
         SET @cCtnTyp1 = ''
         SET @cCtnTyp2 = ''
         SET @cCtnTyp3 = ''
         SET @cCtnTyp4 = ''
         SET @cCtnTyp5 = ''
         SET @nCtnCnt1 = 0
         SET @nCtnCnt2 = 0
         SET @nCtnCnt3 = 0
         SET @nCtnCnt4 = 0
         SET @nCtnCnt5 = 0
         SET @nTotalCube = 0
         SET @nTotalWeight = 0
         SET @nTotalCarton = 0
         
         -- Determine if discrete pick list
         IF EXISTS( SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
         BEGIN            
            -- Determine order is with packing
            IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey)
            BEGIN
               -- Get pack header carton , cube weight, if there is
               SELECT 
                  @nCtnCnt1 = ISNULL( CtnCnt1, 0), 
                  @nCtnCnt2 = ISNULL( CtnCnt2, 0), 
                  @nCtnCnt3 = ISNULL( CtnCnt3, 0), 
                  @nCtnCnt4 = ISNULL( CtnCnt4, 0), 
                  @nCtnCnt5 = ISNULL( CtnCnt5, 0), 
                  @cCtnTyp1 = CtnTyp1,
                  @cCtnTyp2 = CtnTyp2,
                  @cCtnTyp3 = CtnTyp3,
                  @cCtnTyp4 = CtnTyp4,
                  @cCtnTyp5 = CtnTyp5,
                  @nTotalCube = ISNULL( TotCtnCube, 0), 
                  @nTotalWeight = ISNULL( TotCtnWeight, 0)
               FROM PackHeader WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey 
               
               SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND ConfigKey = 'CMSPackingFormula'
            END
            ELSE
               SELECT @cSValue = SValue FROM StorerConfig WITH (NOLOCK) WHERE StorerKey = @c_Storerkey AND ConfigKey = 'CMSNoPackingFormula'
            
            IF @cSValue <> '' AND @cSValue IS NOT NULL
            BEGIN
               DECLARE @cSP_Carton  SYSNAME
               DECLARE @cSP_Cube    SYSNAME
               DECLARE @cSP_Weight  SYSNAME
               DECLARE @cSQL        NVARCHAR( 400)
               DECLARE @cParam      NVARCHAR( 400)
               DECLARE @cPickSlipNo NVARCHAR( 10)
               
               -- Get customize stored procedure
               SELECT 
                  @cSP_Carton = Long, 
                  @cSP_Cube = Notes, 
                  @cSP_Weight = Notes2,
                  @n_Coefficient_carton = CASE WHEN ISNUMERIC(UDF01) = 1 THEN 
                                               CONVERT(float,UDF01) ELSE 1 END,  --NJOW01
                  @n_Coefficient_cube = CASE WHEN ISNUMERIC(UDF02) = 1 THEN
                                               CONVERT(float,UDF02) ELSE 1 END,  --NJOW01
                  @n_Coefficient_weight = CASE WHEN ISNUMERIC(UDF03) = 1 THEN
                                               CONVERT(float,UDF03) ELSE 1 END  --NJOW01
               FROM CodeLkup WITH (NOLOCK)
               WHERE ListName = 'CMSStrateg'
                  AND Code = @cSValue
               
               -- Run carton SP
               SET @n_err = 0
               IF @nCtnCnt1 = 0 AND @nCtnCnt2 = 0 AND @nCtnCnt3 = 0 AND @nCtnCnt4 = 0 AND @nCtnCnt5 = 0 AND OBJECT_ID( @cSP_Carton, 'P') IS NOT NULL
               BEGIN
                  SET @cSQL = 'EXEC ' + @cSP_Carton + ' @cPickSlipNo, @cOrderKey, ' + 
                     '@cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT, ' + 
                     '@nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT'
                  SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), ' + 
                     '@cCtnTyp1 NVARCHAR( 10) OUTPUT, @cCtnTyp2 NVARCHAR( 10) OUTPUT, @cCtnTyp3 NVARCHAR( 10) OUTPUT, @cCtnTyp4 NVARCHAR( 10) OUTPUT, @cCtnTyp5 NVARCHAR( 10) OUTPUT, ' + 
                     '@nCtnCnt1 INT OUTPUT, @nCtnCnt2 INT OUTPUT, @nCtnCnt3 INT OUTPUT, @nCtnCnt4 INT OUTPUT, @nCtnCnt5 INT OUTPUT'
                  EXEC sp_executesql @cSQL, @cParam, @cPickSlipNo, @cOrderKey, 
                     @cCtnTyp1 OUTPUT, @cCtnTyp2 OUTPUT, @cCtnTyp3 OUTPUT, @cCtnTyp4 OUTPUT, @cCtnTyp5 OUTPUT, 
                     @nCtnCnt1 OUTPUT, @nCtnCnt2 OUTPUT, @nCtnCnt3 OUTPUT, @nCtnCnt4 OUTPUT, @nCtnCnt5 OUTPUT
                  SET @n_err = @@ERROR                  
               END
               --NJOW02
               SET @nCtnCnt1 = CONVERT(int, ISNULL(@nCtnCnt1,0) * @n_Coefficient_carton)     
               SET @nCtnCnt2 = CONVERT(int, ISNULL(@nCtnCnt2,0) * @n_Coefficient_carton)     
               SET @nCtnCnt3 = CONVERT(int, ISNULL(@nCtnCnt3,0) * @n_Coefficient_carton)     
               SET @nCtnCnt4 = CONVERT(int, ISNULL(@nCtnCnt4,0) * @n_Coefficient_carton)     
               SET @nCtnCnt5 = CONVERT(int, ISNULL(@nCtnCnt5,0) * @n_Coefficient_carton)                 

               -- Run cube SP
               IF @nTotalCube <> 0 
                  SET @nStdCube = ISNULL(@nTotalCube,0) * @n_Coefficient_cube --NJOW02 
               ELSE
                  IF @n_err = 0 AND OBJECT_ID( @cSP_Cube, 'P') IS NOT NULL
                  BEGIN
                     SET @cSQL = 'EXEC ' + @cSP_Cube + ' @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, @nCurrentTotalCube, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5'
                     SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalCube FLOAT OUTPUT, @nCurrentTotalCube FLOAT, @nCtnCnt1 INT, @nCtnCnt2 INT, @nCtnCnt3 INT, @nCtnCnt4 INT, @nCtnCnt5 INT'
                     EXEC sp_executesql @cSQL, @cParam, @cPickSlipNo, @cOrderKey, @nTotalCube OUTPUT, NULL, @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5
                     SET @n_err = @@ERROR

                     --NJOW01
                     SET @nTotalCube = ISNULL(@nTotalCube,0) * @n_Coefficient_cube             

                     SET @nStdCube = @nTotalCube
                  END
   
               -- Run weight SP
               IF @nTotalWeight <> 0 
                  SET @nStdGrossWgt = ISNULL(@nTotalWeight,0) * @n_Coefficient_weight --NJOW02     
               ELSE
                  IF @n_err = 0 AND OBJECT_ID( @cSP_Weight, 'P') IS NOT NULL 
                  BEGIN
                     SET @cSQL = 'EXEC ' + @cSP_Weight + ' @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT'
                     SET @cParam = '@cPickSlipNo NVARCHAR( 10), @cOrderKey NVARCHAR( 10), @nTotalWeight FLOAT OUTPUT'
                     EXEC sp_executesql @cSQL, @cParam, @cPickSlipNo, @cOrderKey, @nTotalWeight OUTPUT
                     SET @n_err = @@ERROR

                     --NJOW01
                     SET @nTotalWeight = ISNULL(@nTotalWeight,0) * @n_Coefficient_weight             
                     
                     SET @nStdGrossWgt = @nTotalWeight
                  END
               
               IF @n_err <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Failed exec customize stored procedure. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
               END
            END
         END
         
         SET @nTotalCarton = @nCtnCnt1 + @nCtnCnt2 + @nCtnCnt3 + @nCtnCnt4 + @nCtnCnt5
         
         -- SOS216105 end. Configurable SP to calc carton, cube and weight

         --(Kc01) - start    
         -- Auto populate Carton QTY from PackingInfo into MbolDetail CtnCnt1 if storerconfig setup is:     
         -- CAPTURE_PACKINFO = 1  and  MBOLSUMCTNCNT2TOTCTN = 2 or MBOLSUMCTNCNT2TOTCTN = 1    
         SET @b_success = 0    
         SET @c_authority = '0'    
         --SET @n_TotalCartons = 0    
                
         EXECUTE nspGetRight null,           -- facility    
                  @c_Storerkey,              -- Storerkey    
                  null,                      -- Sku    
                  'CAPTURE_PACKINFO',        -- Configkey    
                  @b_success    output,    
                  @c_authority  output,     
                  @n_err        output,    
                  @c_errmsg     output    
    
         IF @c_authority = '1' AND @b_success = 1    
         BEGIN    
            SET @b_success = 0    
            SET @c_authority = '0'    
            EXECUTE nspGetRight null,           -- facility    
                     @c_Storerkey,              -- Storerkey    
                     null,                      -- Sku    
                     'MBOLSUMCTNCNT2TOTCTN',    -- Configkey    
                     @b_success    output,    
                     @c_authority  output,     
                     @n_err        output,    
                     @c_errmsg     output    
    
            IF (@c_authority = '1' OR @c_authority = '2') AND @b_success = 1    
            BEGIN    
               -- SHONG01  
               IF EXISTS(SELECT 1 FROM PACKHEADER WITH (NOLOCK)   
                         WHERE PACKHEADER.Orderkey = @cOrderkey)  
               BEGIN  
                  SELECT @nTotalCarton = COUNT(Distinct CartonNo)    
                  FROM PACKDETAIL WITH (NOLOCK)    
                  JOIN PACKHEADER WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipno)    
                  WHERE PACKHEADER.Orderkey = @cOrderkey  
               END   
               ELSE  
               BEGIN  
                  IF EXISTS(SELECT 1 FROM RefKeyLookUp WITH (NOLOCK)   
                            WHERE RefKeyLookUp.Orderkey = @cOrderkey)  
                  BEGIN  
                     SELECT @nTotalCarton = COUNT(Distinct LabelNo)    
                     FROM PACKDETAIL WITH (NOLOCK)    
                     WHERE PACKDETAIL.PickSlipNo IN (SELECT DISTINCT PickSlipNo    
                                                     FROM RefKeyLookUp WITH (NOLOCK)   
                                                     WHERE RefKeyLookUp.Orderkey = @cOrderkey)   
                  END   
               END   
            END    
         END    
         --(Kc01) - end         
         
         --NJOW03 Start
         SET @b_success = 0    
         SET @c_authority = '0'    
                
         EXECUTE nspGetRight null,           -- facility    
                  @c_Storerkey,              -- Storerkey    
                  null,                      -- Sku    
                  'UpdOrdDelDate2MbolDptDate',   -- Configkey    
                  @b_success    output,    
                  @c_authority  output,     
                  @n_err        output,    
                  @c_errmsg     output    
    
         IF @c_authority = '1' AND @b_success = 1    
         BEGIN    
            IF (SELECT COUNT(1) FROM MBOLDETAIL(NOLOCK) WHERE MBOLKey = @cMBOLKey) < 1
            BEGIN
            	 UPDATE MBOL WITH (ROWLOCK)
            	 SET MBOL.Departuredate = (SELECT Deliverydate FROM ORDERS(NOLOCK) WHERE Orderkey = @cOrderKey) 
            	 WHERE MBOL.Mbolkey = @cMBOLKey              	 
            END            
         END             
         --NJOW03 End    
              
         INSERT INTO MBOLDETAIL
            (MBOLKey,            MBOLLineNumber, 
             OrderKey,           LoadKey, 
             ExternOrderKey,     DeliveryDate, 
             Weight,             Cube,
             Description,        OrderDate,
             InvoiceNo,          AddWho,
             TotalCartons,       CtnCnt1,          --(Kc01)
             CtnCnt2,            CtnCnt3,          --SOS216105
             CtnCnt4,            CtnCnt5)          --SOS216105
         VALUES
            (@cMBOLKey,          @cMBOLLineNumber,
             @cOrderKey,         @cLoadKey,
             @cExternOrderKey,   @dDelivery_Date, 
             @nStdGrossWgt,      @nStdCube,     
             SUBSTRING( RTRIM( @cCustomerName), 1, 30),     @dOrderDate,   -- (james01)
             @cInvoiceNo,        '*' + dbo.fnc_RTrim(sUser_sName()), 
             @nTotalCarton,      @nCtnCnt1,       --SOS216105
             @nCtnCnt2,          @nCtnCnt3,       --SOS216105
             @nCtnCnt4,          @nCtnCnt5)       --SOS216105
                                  
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed to Table MBOL Detail. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
         END
      END -- MBOL Detail not exists
      ELSE
      BEGIN
         UPDATE MBOLDETAIL WITH (ROWLOCK) 
         SET    Weight = @nStdGrossWgt, 
                Cube   = @nStdCube, 
                TrafficCop = NULL
               ,EditDate = GETDATE() -- KHLim01
         WHERE  MBOLKey = @cMBOLKey
         AND      Orderkey = @cOrderKey
         AND    Loadkey = @cLoadkey -- SOS39592 
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL Detail. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
         END
      END          
   END 

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @cCarrierKey    NVARCHAR(10), 
              @cVoyageNumber  NVARCHAR(30),
              @cTruckSize     NVARCHAR(10),
              @cTruckType     NVARCHAR(10)  
   
      SELECT @cCarrierKey = CarrierKey, 
             @cVoyageNumber = VoyageNumber
      FROM   MBOL (NOLOCK) 
      WHERE MBOLKey = @cMBOLKey 
      
      IF dbo.fnc_RTrim(@cCarrierKey) IS NULL OR dbo.fnc_RTrim(@cCarrierKey) = ''
      BEGIN 
         SET @cTruckSize =''
         SET @cCarrierKey = ''
            
         SELECT @cCarrierKey = ISNULL(CarrierKey, ''), 
                @cTruckSize = ISNULL(TruckSize, '')
         FROM   LOADPLAN (NOLOCK)   
         WHERE  LoadKey = @cLoadKey 
            
         SELECT @cTruckType = ISNULL(TruckType, '')
         FROM  ROUTEMASTER (NOLOCK)
         WHERE Route = @cRoute 
   
         UPDATE MBOL WITH (ROWLOCK) 
        -- SET VoyageNumber = @cRoute,                                    --(CS01)
           SET VoyageNumber = CASE WHEN ISNULL(VoyageNumber,'') = '' THEN @cRoute ELSE VoyageNumber END,   --(CS01)
               CarrierKey = @cCarrierKey,
               Vessel     = CASE WHEN Vessel = '' THEN ISNULL(@cTruckSize,'') ELSE ISNULL(Vessel,'') END,
               VesselQualifier = CASE WHEN VesselQualifier = '' THEN @cTruckType ELSE VesselQualifier END ,
               TRAFFICCOP = NULL,
               [Route] = CASE WHEN ISNULL([Route],'') = '' THEN @cRoute ELSE [Route] END, --WL01
               EditDate = GETDATE(), -- KHLim01
               EditWho = SUSER_SNAME() --WL01
         WHERE MBOLKey = @cMbolKey 
   
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72807   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
         END

         --WL02 Start
         SET @b_success = 0    
         SET @c_authority = '0'    
                
         EXECUTE nspGetRight 
                  @cFacility,                -- facility    
                  @c_Storerkey,              -- Storerkey    
                  null,                      -- Sku    
                  'DefaultCarrierAgent',     -- Configkey    
                  @b_success       OUTPUT,    
                  @c_GetAuthority  OUTPUT,     
                  @n_err           OUTPUT,    
                  @c_errmsg        OUTPUT    

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72808   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error executing nspGetRight. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
         END
         
         IF ISNULL(@c_GetAuthority,'') <> '' AND @n_err = 0
         BEGIN
            IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'CarrierAgt' AND Code = @c_GetAuthority)
            BEGIN
               UPDATE MBOL WITH (ROWLOCK)
               SET Carrieragent = @c_GetAuthority,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
               WHERE MBOLKey = @cMbolKey
            END
         END
         --WL02 End   
      END
   END 
   
   --(CS02) - START  --NJOW04
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SET @b_Success = 0
      SET @c_POSTAddMBOLDETAILSP = ''
      EXEC nspGetRight  
            @c_Facility  = @cFacility
          , @c_StorerKey = @c_StorerKey 
          , @c_sku       = NULL
          , @c_ConfigKey = 'POSTAddMBOLDETAILSP'  
          , @b_Success   = @b_Success                  OUTPUT  
          , @c_authority = @c_POSTAddMBOLDETAILSP        OUTPUT   
          , @n_err       = @n_err                      OUTPUT   
          , @c_errmsg    = @c_errmsg                   OUTPUT  
   
      IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_POSTAddMBOLDETAILSP AND TYPE = 'P')
      BEGIN
         SET @b_Success = 0  
         EXECUTE dbo.ispPOSTAddMBOLDETAILWrapper 
                 @c_mbolkey           = @cMBOLKey
               , @c_orderkey          = @cOrderKey
               , @c_loadkey           = @cLoadKey              
               , @c_POSTAddMBOLDETAILSP= @c_POSTAddMBOLDETAILSP
               , @c_MbolDetailLineNumber = @cMBOLLineNumber 
               , @b_Success = @b_Success     OUTPUT  
               , @n_Err     = @n_err         OUTPUT   
               , @c_ErrMsg  = @c_errmsg      OUTPUT  
              -- , @b_debug   = 0 
   
         IF @n_err <> 0  
         BEGIN 
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72811   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed on Table MBOL Detail. (isp_InsertMBOLDetail)' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))
           -- GOTO RollbackTran
         END 
      END 
   END
   --(CS02) - End         

   /* #INCLUDE <TRMBOHU2.SQL> */
   
   /***** End Add by DLIM *****/
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_InsertMBOLDetail'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- procedure

GO