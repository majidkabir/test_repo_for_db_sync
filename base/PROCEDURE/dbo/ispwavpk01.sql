SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispWAVPK01                                         */
/* Creation Date: 23-Feb-2016                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#361966-Carters SZ - pre-cartonization                   */
/*                                                                      */
/* Called By: Wave                                                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 24-May-2016  NJOW01   1.0  361966-revise cartonization logic         */  
/* 25-Aug-2016  SHONG    1.1  Using Temp PickDetail_WIP table to reduce */
/*                            blocking for pickdetail                   */        
/* 28-Jun-2017  Leong    1.2  IN00388803 - Revise Logic.                */
/* 19-Sep-2017  TLTING01 1.2  Performance tune - delete WIP by row      */
/* 08-Jun-2018  NJOW02   1.3  WMS-5238 Change logic                     */ 
/* 10-Nov-2018  NJOW03   1.4  WMS-6698 change sorting and add search    */
/*                            carton step. Performance Tune             */
/* 19-Nov-2018  TLTING02 1.5  Performance tune                          */
/* 30-Sep-2019  NJOW04   1.6  Fix recalculate current carton size to    */
/*                            best fit before new carton                */
/* 22-Jan-2020  NJOW05   1.7  WMS-11882 Include SKIP HOP logic          */
/************************************************************************/

CREATE PROC [dbo].[ispWAVPK01]   
   @c_Wavekey   NVARCHAR(10),  
   @b_Success   INT      OUTPUT,
   @n_Err       INT      OUTPUT, 
   @c_ErrMsg    NVARCHAR(250) OUTPUT  
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @c_LabelNo NVARCHAR(20),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20),
           @n_Qty INT,
           @c_UOM NVARCHAR(10),           
           @c_UCCNo NVARCHAR(20),
           @c_PrevLoadKey NVARCHAR(10),
           @c_PrevPrePackFlag NVARCHAR(1),
           @c_PrevCartonGroup NVARCHAR(18),
           @n_PrevMaxCartonUnits INT,
           @c_PrevAssortment NVARCHAR(18),
           @c_PrevCubingIndicator NVARCHAR(20), 
           @c_PrevStyle NVARCHAR(20),
           @c_PrevColor NVARCHAR(10),
           @c_PrevSku NVARCHAR(20),
           @c_LoadKey NVARCHAR(10),
           @c_CartonType NVARCHAR(18),
           @c_CartonGroup NVARCHAR(18),
           @c_FindCartonGroup NVARCHAR(18),
           @n_CartonNo INT,
           @c_Assortment NVARCHAR(18), --assortment number
           @n_NbrUnitsInPpacks INT, --component qty per parent sku (assortment)
           @c_CubingIndicator NVARCHAR(20), 
           @c_PrePackFlag NCHAR(1), --prepack flag 0 for none bom sku, 1,2,3 for assortment (BOM) (3 not used at the moment)
           @c_PickslipNo NVARCHAR(10),
           @c_DispatchPiecePickMethod NVARCHAR(10),
           @n_MaxCartonUnits INT, --maximum qty can fit into the carton. smaller unit convert by sku.busr1
           @c_SourceType NVARCHAR(50),
           @n_CartonCube DECIMAL(16,6),
           @n_AssortmentCube DECIMAL(16,6), --cube per parent sku (assortment)
           @n_AssortmentQty INT, --number of assortment
           @n_TotalCubeRequire DECIMAL(16,6),
           @c_NewCarton NCHAR(1),
           @n_BalCartonCube DECIMAL(16,6), --the open carton available space in cube
           @n_BalCartonQty INT, --the open carton available space in qty
           @n_CartnNo INT,
           @n_NoOfAssortCanFit INT,
           @n_NoOfQtyCanFit INT,
           @n_PickQty INT,
           @n_PackQty INT,
           @n_splitqty INT,
           @c_PickDetailKey NVARCHAR(10),
           @c_NewPickdetailKey NVARCHAR(10),
           @c_Style NVARCHAR(20),
           @c_Color NVARCHAR(10),
           @n_StdCube DECIMAL(16,6),
           @n_StdGrossWgt DECIMAL(15,4),
           @n_SkuQty INT,
           @n_CartonWeight DECIMAL(15,4),
           @c_PrevPrePackGroupCode NVARCHAR(10), --NJOW01
           @c_PrePackGroupCode NVARCHAR(10), --NJOW01
           @n_TotUnitPerAssortment INT, --NJOW01 	qty * sku.busr1 per assortment
           @n_UnitPerQty INT, --NJOW01  1 qty = n component units (sku.busr1)    orderdetail.freegoodqty(comp units per assortment) / busr1 = number of qty per assortment
           @c_Lottable01_BU NVARCHAR(18), --NJOW02
           @c_PrevLottable01_BU NVARCHAR(18) --NJOW02
   
   --NJOW03        
   DECLARE @c_Facility NVARCHAR(5),  
           @c_SortMode NVARCHAR(10), 
           @cur_PICKDET_BOM CURSOR,
           @cur_PICKDET_SKU CURSOR,      
           @CUR_PACKSKU CURSOR,
           @n_CartonCube_Tmp DECIMAL(16,6), 
           @c_CartonType_Tmp NVARCHAR(18), 
           @n_Stdcube_tmp DECIMAL(16,6),
           @n_Findcube_tmp DECIMAL(16,6)
           
   DECLARE @c_WIP_PickDetailKey nvarchar(18), 
           @n_UOMQty            INT  
                           
   DECLARE @n_Continue   INT,
           @n_StartTCnt  INT,
           @n_debug      INT
   
 	 IF @n_err =  1
	    SET @n_debug = 1
	 ELSE
	    SET @n_debug = 0		 
                                                     
	SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_success = 1 
	
	 IF @@TRANCOUNT = 0
	    BEGIN TRAN
   	 	   
   SELECT TOP 1 @c_DispatchPiecePickMethod = WAVE.DispatchPiecePickMethod,
                @c_Storerkey = ORDERS.Storerkey,
                @c_Facility = ORDERS.Facility --NJOW03
   FROM WAVE (NOLOCK)
   JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey        
   WHERE WAVE.Wavekey = @c_Wavekey

   IF ISNULL(@c_DispatchPiecePickMethod,'') = 'I' --IFC will not have pre-cartonization,it use PTS(put to light) for packing
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38010     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': IFC Wave is not necessary to generate pre-cartonization (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END
            
   IF ISNULL(@c_DispatchPiecePickMethod,'') NOT IN('I','T','H','S') 
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38020     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Invalid Code to determine IFC or Traditional or Hub or Skip Hop (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP 
   END
   
    --NJOW03
	  SELECT TOP 1 @c_SortMode = UDF01
    FROM CODELKUP (NOLOCK)
    WHERE ListName = 'CARSORT'
    AND Code = @c_Facility
    AND Storerkey = @c_Storerkey
    
    IF ISNULL(@c_SortMode,'') = ''
       SET @c_SortMode = 'S1'
   
   --Create temporary table
   IF @n_continue IN(1,2)
   BEGIN
      CREATE TABLE #TMP_ASSORTMENTDETAIL
         (PrePackGroupCode NVARCHAR(10) NULL, --NJOW01
          Assortment NVARCHAR(18) NULL, 
          Storerkey NVARCHAR(15) NULL,
          Sku NVARCHAR(20) NULL, 
          NbrUnitsInPpacks INT NULL,
          AssortmentQty INT NULL,
          StdGrossWgt DECIMAL(15,4) NULL,
          StdCube DECIMAL(16,6) NULL,
          UnitPerQty INT NULL)  --NJOW01

      CREATE TABLE #TMP_PACKDET
         (Storerkey NVARCHAR(15) NULL,
          Sku NVARCHAR(20) NULL, 
          Qty INT NULL,
          StdCube DECIMAL(16,6) NULL,
          StdGrossWgt DECIMAL(15,4) NULL,
          UnitPerQty INT NULL,
          Measurement NVARCHAR(5) NULL)  --NJOW01 NJOW03
      
      --NJOW03    
      CREATE TABLE #PickDetail_WIP(
      	[PickDetailKey] [nvarchar](18) NOT NULL PRIMARY KEY,
      	[CaseID] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[PickHeaderKey] [nvarchar](18) NOT NULL,
      	[OrderKey] [nvarchar](10) NOT NULL,
      	[OrderLineNumber] [nvarchar](5) NOT NULL,
      	[Lot] [nvarchar](10) NOT NULL,
      	[Storerkey] [nvarchar](15) NOT NULL,
      	[Sku] [nvarchar](20) NOT NULL,
      	[AltSku] [nvarchar](20) NOT NULL DEFAULT (' '),
      	[UOM] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[UOMQty] [int] NOT NULL DEFAULT ((0)),
      	[Qty] [int] NOT NULL DEFAULT ((0)),
      	[QtyMoved] [int] NOT NULL DEFAULT ((0)),
      	[Status] [nvarchar](10) NOT NULL DEFAULT ('0'),
      	[DropID] [nvarchar](20) NOT NULL DEFAULT (''),
      	[Loc] [nvarchar](10) NOT NULL DEFAULT ('UNKNOWN'),
      	[ID] [nvarchar](18) NOT NULL DEFAULT (' '),
      	[PackKey] [nvarchar](10) NULL DEFAULT (' '),
      	[UpdateSource] [nvarchar](10) NULL DEFAULT ('0'),
      	[CartonGroup] [nvarchar](10) NULL,
      	[CartonType] [nvarchar](10) NULL,
      	[ToLoc] [nvarchar](10) NULL  DEFAULT (' '),
      	[DoReplenish] [nvarchar](1) NULL DEFAULT ('N'),
      	[ReplenishZone] [nvarchar](10) NULL DEFAULT (' '),
      	[DoCartonize] [nvarchar](1) NULL DEFAULT ('N'),
      	[PickMethod] [nvarchar](1) NOT NULL DEFAULT (' '),
      	[WaveKey] [nvarchar](10) NOT NULL DEFAULT (' '),
      	[EffectiveDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[AddWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[EditDate] [datetime] NOT NULL DEFAULT (getdate()),
      	[EditWho] [nvarchar](128) NOT NULL DEFAULT (suser_sname()),
      	[TrafficCop] [nvarchar](1) NULL,
      	[ArchiveCop] [nvarchar](1) NULL,
      	[OptimizeCop] [nvarchar](1) NULL,
      	[ShipFlag] [nvarchar](1) NULL DEFAULT ('0'),
      	[PickSlipNo] [nvarchar](10) NULL,
      	[TaskDetailKey] [nvarchar](10) NULL,
      	[TaskManagerReasonKey] [nvarchar](10) NULL,
      	[Notes] [nvarchar](4000) NULL,
      	[MoveRefKey] [nvarchar](10) NULL DEFAULT (''),
      	[WIP_Refno] [nvarchar](30) NULL DEFAULT (''),
        [Channel_ID] [bigint] NULL DEFAULT ((0)))	         

        CREATE INDEX PDWIP_OrderLN ON #PickDetail_WIP (Orderkey, OrderLineNumber)  --NJOW03         
        CREATE INDEX PDWIP_sKU ON #PickDetail_WIP (Storerkey, Sku)  --NJOW03         
   END
      
   --Validation            
   IF @n_continue IN(1,2) 
   BEGIN
      IF EXISTS(SELECT 1 FROM PickDetail PD WITH (NOLOCK) 
                JOIN  WAVEDETAIL WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey --NJOW03
                WHERE PD.Status='4' AND PD.Qty > 0 
                AND  WD.Wavekey = @c_WaveKey)
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38030     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Short Pick with Qty > 0 (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
      END

      -- tlting01
      IF EXISTS (SELECT 1
                 FROM WAVEDETAIL WD (NOLOCK)
                 JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey   
                 WHERE WD.Wavekey = @c_Wavekey
                 AND EXISTS (SELECT 1 FROM PACKHEADER PH (NOLOCK) 
                             JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno 
                             WHERE PH.Loadkey =  O.Loadkey AND  
                             (PH.Orderkey = '' OR PH.Orderkey IS NULL) ) )  --NJOW03
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38040     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The wave has been pre-cartonized. Not allow to run again. (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END
   END
 
   --Retrieve pickdetail and validation
   IF @n_continue IN(1,2) 
   BEGIN
      SELECT O.Loadkey,
             PD.Storerkey, 
             PD.Sku, 
             SUM(PD.Qty) AS Qty, 
             PD.UOM,
             ISNULL(PD.DropID,'') AS UCCNo,
             ISNULL(OD.Userdefine08,'') AS CartonGroup, 
             CASE WHEN CHARINDEX('-',OD.Userdefine03) > 0 --NJOW01
                  THEN LEFT(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) - 1)
                  ELSE '' END AS PrePackGroupCode,
             CASE WHEN CHARINDEX('-',OD.Userdefine03) > 0 
                  THEN SUBSTRING(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) + 1 , LEN(OD.Userdefine03))
                  ELSE '' END AS Assortment,
             CASE WHEN ISNUMERIC(SKU.Busr1) = 1 AND SKU.Busr1 <> '0' THEN --NJOW01 number of qty per assortment
                    OD.FreeGoodQty / CAST(SKU.Busr1 AS INT)
                  ELSE
                    OD.FreeGoodQty END AS NbrUnitsInPpacks,
             O.Userdefine05 AS CubingIndicator,
             O.SpecialHandling AS PrePackFlag,
             --CASE WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT) ELSE 0 END AS MaxCartonUnits,
             CASE WHEN CLK.Code IS NOT NULL THEN 1
                  WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT)
                  WHEN LEFT(OD.Userdefine08,1) = 'M' AND ISNUMERIC(SUBSTRING(OD.Userdefine08,2,10)) = 1 THEN CAST(SUBSTRING(OD.Userdefine08,2,10) AS INT)
                  ELSE 0 END AS MaxCartonUnits, --NJOW02 
             SKU.Stdcube,
             SKU.StdGrossWgt, 
             SKU.Style,
             SKU.Color,
             CASE WHEN ISNUMERIC(SKU.Busr1) = 1 THEN --NJOW01 number of component units per qty
                  CAST(SKU.Busr1 AS INT)
             ELSE 1 END AS UnitperQty,
             LA.Lottable01 AS Lottable01_BU, --NJOW02
             SKU.Measurement --NJOW03
      INTO #TMP_PICKDETAIL             
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW02      
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
      JOIN STORER S (NOLOCK) ON O.StorerKey = S.StorerKey
      LEFT JOIN CODELKUP CLK (NOLOCK) ON OD.Userdefine08 = CLK.Code AND CLK.ListName = 'CASAL' --NJOW02
      WHERE WD.Wavekey = @c_Wavekey
      GROUP BY O.Loadkey,
               PD.Storerkey, 
               PD.Sku, 
               PD.UOM,      
               ISNULL(PD.DropID,''),           
               ISNULL(OD.Userdefine08,''), 
               CASE WHEN CHARINDEX('-',OD.Userdefine03) > 0 
                    THEN LEFT(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) - 1)
                    ELSE '' END, --NJOW01
               CASE WHEN CHARINDEX('-',OD.Userdefine03) > 0 
                    THEN SUBSTRING(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) + 1 , LEN(OD.Userdefine03))
                    ELSE '' END,
               CASE WHEN ISNUMERIC(SKU.Busr1) = 1 AND SKU.Busr1 <> '0' THEN --NJOW01
                    OD.FreeGoodQty / CAST(SKU.Busr1 AS INT)
                  ELSE
                    OD.FreeGoodQty END, 
               O.Userdefine05,
               O.SpecialHandling,
               --CASE WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT) ELSE 0 END,
              CASE WHEN CLK.Code IS NOT NULL THEN 1
                   WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT)
                   WHEN LEFT(OD.Userdefine08,1) = 'M' AND ISNUMERIC(SUBSTRING(OD.Userdefine08,2,10)) = 1 THEN CAST(SUBSTRING(OD.Userdefine08,2,10) AS INT)
                   ELSE 0 END, --NJOW02 
               SKU.Stdcube, 
               SKU.StdGrossWgt,
               SKU.Style,
               SKU.Color,
               CASE WHEN ISNUMERIC(SKU.Busr1) = 1 THEN --NJOW01
                  CAST(SKU.Busr1 AS INT)
               ELSE 1 END,
               LA.Lottable01 ,--NJOW02                             
               SKU.Measurement --NJOW03
               
       CREATE INDEX TP_prepackflag ON #TMP_PICKDETAIL(PrePackFlag)  --NJOW03
       CREATE INDEX TP_UOM ON #TMP_PICKDETAIL(UOM)  --NJOW03
       CREATE INDEX TP_Cubeind ON #TMP_PICKDETAIL(CubingIndicator)  --NJOW03              
                              
       IF @n_debug = 1
          SELECT * FROM #TMP_PICKDETAIL       
          
       IF (SELECT COUNT(1) FROM #TMP_PICKDETAIL) = 0
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38050     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': No pickdetail found for pre-cartonization (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END

       IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL TP 
                  WHERE TP.PrePackFlag IN('3')) --NJOW01                 
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38055     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pre-PackFlag(specialhandling) ''3'' Is Not Required At This Time. (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END                              
                             
       IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL TP 
                  WHERE TP.PrePackFlag NOT IN('0','1','2','3'))                  
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38060     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found invalid Pre-PackFlag(specialhandling). The value must be 0,1,2,3 (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END                              

       IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL TP 
                  WHERE TP.CubingIndicator NOT IN('51','61','62','64')
                  AND TP.PrePackFlag = '0')  --NJOW01                
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38070     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found invalid Cubic Indicator(Userdfine05) For PrePack Flag 0. The value must be 51,61,62,64 (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END                              
               
       --IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL WHERE PrePackFlag IN('1','2','3') AND CubingIndicator <> '51')
       --BEGIN
       --  SELECT @n_continue = 3  
       --  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38080     
       --  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Pre-PackFlag 1,2,3 with Cubic Indicator other than 51 is not allowed (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
       --  GOTO QUIT_SP 
       --END               

       IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL TP 
                  WHERE TP.PrePackFlag IN('1','2','3')
                  AND ISNULL(TP.Assortment,'')='')
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38090     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Empty assortment is found for Pre-PackFlag 1,2,3 (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END               
       
       /*
       SET @c_Assortment = ''
       SELECT TOP 1 @c_Assortment = TP.Assortment
       FROM #TMP_PICKDETAIL TP 
       LEFT JOIN BILLOFMATERIAL BOM (NOLOCK) ON TP.Assortment = BOM.Notes
       LEFT JOIN SKU (NOLOCK) ON TP.Storerkey = SKU.Storerkey AND TP.Sku = SKU.Sku
       WHERE TP.PrePackFlag IN('1','2','3')
       AND BOM.Notes IS NULL 
       
       IF ISNULL(@c_Assortment,'') <> ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38100     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Bill Of Material is not found for Assortment '''+ RTRIM(@c_Assortment) + ''' of Pre-PackFlag 1,2,3 (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END          
       */

       SET @c_Assortment = ''
       SELECT TOP 1 @c_Assortment = TP.Assortment
       FROM #TMP_PICKDETAIL TP 
       ---LEFT JOIN BILLOFMATERIAL BOM (NOLOCK) ON TP.Assortment = BOM.Notes
       LEFT JOIN SKU (NOLOCK) ON TP.Storerkey = SKU.Storerkey AND TP.Sku = SKU.Sku
       --LEFT JOIN SKU COMP (NOLOCK) ON BOM.Storerkey = COMP.Storerkey AND BOM.ComponentSku = COMP.Sku
       WHERE TP.PrePackFlag IN('1','2','3')
       AND ISNULL(SKU.Stdcube,0) = 0 
       AND ISNULL(TP.MaxCartonUnits,0) = 0 --NJOW01
       --AND ISNULL(COMP.Stdcube,0) = 0 

       IF ISNULL(@c_Assortment,'') <> ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38110     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Assortment '''+ RTRIM(@c_Assortment) + ''' Cube not setup (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END          
       
       SET @c_Sku = ''
       SET @c_Assortment = ''
       SELECT TOP 1 @c_Assortment = TP.Assortment, @c_Sku = TP.Sku FROM #TMP_PICKDETAIL TP 
       WHERE TP.PrePackFlag IN('1','2','3')
       GROUP BY TP.PrePackGroupCode, TP.Assortment, TP.Storerkey, TP.Sku, TP.NbrUnitsInPpacks  --NJOW01
       HAVING COUNT(DISTINCT TP.NbrUnitsInPpacks) > 1 OR SUM(CASE WHEN TP.NbrUnitsInPpacks = 0 THEN 1 ELSE 0 END) > 0

       IF ISNULL(@c_Sku,'') <> ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38120     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Zero NbrUnitsInPpacks(FreeGoodQty/SKU.Busr1) value or more than one NbrUnitsInPpacks value found for the Sku '''+ RTRIM(@c_Sku) + ''' of assortment '''+ RTRIM(@c_Assortment) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  --NJOW01
         GOTO QUIT_SP 
       END          

       SET @c_Sku = ''
       SELECT TOP 1 @c_Sku = TP.Sku FROM #TMP_PICKDETAIL TP 
       JOIN SKU (NOLOCK) ON TP.Storerkey = SKU.Storerkey AND TP.Sku = SKU.Sku
       WHERE TP.PrePackFlag = '0'
       AND SKU.Stdcube = 0
       AND ISNULL(TP.MaxCartonUnits,0) = 0 --NJOW01
       
       IF ISNULL(@c_Sku,'') <> ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38130     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cube not setup for Sku '''+ RTRIM(@c_Sku) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END          
        
       INSERT INTO #TMP_ASSORTMENTDETAIL (PrePackGroupCode, Assortment, Storerkey, Sku, NbrUnitsInPpacks, AssortmentQty) 
       SELECT TP.PrePackGroupCode, TP.Assortment, TP.Storerkey, TP.Sku, TP.NbrUnitsInPpacks, (SUM(TP.Qty) / TP.NbrUnitsInPpacks) AS AssortmentQty -- IN00388803
       FROM #TMP_PICKDETAIL TP 
       WHERE TP.PrePackFlag IN('1','2','3')
       GROUP BY TP.PrePackGroupCode, TP.Assortment, TP.Storerkey, TP.Sku, TP.NbrUnitsInPpacks
       
       SET @c_Assortment = ''
       SET @c_PrePackGroupCode = '' --NJOW01
       SELECT TOP 1 @c_Assortment = AD.Assortment, @c_PrePackGroupCode  = AD.PrePackGroupCode FROM #TMP_ASSORTMENTDETAIL AD
       GROUP BY AD.PrePackGroupCode, AD.Assortment 
       HAVING COUNT(DISTINCT AD.AssortmentQty) > 1

       IF ISNULL(@c_Assortment,'') <> ''
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38140     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Component sku order qty of PrePackGroupCode '''+ RTRIM(@c_PrePackGroupCode) + ''' assortment '''+ RTRIM(@c_Assortment) + ''' is not tally (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END          
       
       IF EXISTS (SELECT 1 FROM #TMP_PICKDETAIL TP 
                  LEFT JOIN CARTONIZATION CZ (NOLOCK) ON TP.CartonGroup = CZ.CartonizationGroup
                  WHERE ISNULL(TP.CartonGroup,'') = '' OR ISNULL(CZ.Cube,0) = 0) --NJOW01        
       BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38145     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Found Carton group at Orderdetail.Userdefine08 is empty or without Cube setup in cartonization (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP 
       END                              
   END  
   
   IF @n_StartTCnt = 0
      BEGIN TRAN
   
   --Remove pickdetail caseid 
   IF @n_continue IN(1,2) 
   BEGIN 

/*   	   	     
   	UPDATE PICKDETAIL WITH (ROWLOCK)
   	   SET PICKDETAIL.CaseId = '',
   	      PICKDETAIL.TrafficCop = NULL
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN PICKDETAIL ON WD.Orderkey = PICKDETAIL.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
*/
      /*  --NJOW03 Remove
      IF EXISTS(SELECT 1 FROM PickDetail_WIP WITH (NOLOCK)
      
                WHERE WaveKey = @c_Wavekey)
      BEGIN
         -- tlting01
         DECLARE CUR_DELPickDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey 
         FROM PickDetail_WIP WITH (NOLOCK)
         WHERE WaveKey = @c_Wavekey
 
         OPEN CUR_DELPickDetail

         FETCH FROM CUR_DELPickDetail INTO @c_WIP_PickDetailKey 

         WHILE @@FETCH_STATUS = 0
         BEGIN
            DELETE PickDetail_WIP WITH (ROWLOCK)
            WHERE PickDetailKey = @c_WIP_PickDetailKey 
            FETCH FROM CUR_DELPickDetail INTO @c_WIP_PickDetailKey 
         END

         CLOSE CUR_DELPickDetail
         DEALLOCATE CUR_DELPickDetail
         SET @c_WIP_PickDetailKey = ''
      END 
      */
      
      INSERT INTO #PickDetail_WIP  --NJOW03
      (
      	PickDetailKey,      CaseID,      	 PickHeaderKey,
      	OrderKey,           OrderLineNumber, Lot,
      	Storerkey,          Sku,      	    AltSku,     UOM,
      	UOMQty,      	     Qty,      	    QtyMoved,   [Status],
      	DropID,      	     Loc,      	    ID,      	PackKey,
      	UpdateSource,       CartonGroup,     CartonType,
      	ToLoc,      	     DoReplenish,     ReplenishZone,
      	DoCartonize,        PickMethod,      WaveKey,
      	EffectiveDate,      AddDate,      	 AddWho,
      	EditDate,           EditWho,      	 TrafficCop,
      	ArchiveCop,         OptimizeCop,     ShipFlag,
      	PickSlipNo,         TaskDetailKey,   TaskManagerReasonKey,
      	Notes,      	     MoveRefKey,				Channel_ID
      )
      SELECT PD.PickDetailKey,  CaseID='',   PD.PickHeaderKey, 
      	PD.OrderKey,       PD.OrderLineNumber, PD.Lot,
      	PD.Storerkey,      PD.Sku,      	      PD.AltSku,        PD.UOM,
      	PD.UOMQty,      	 PD.Qty,      	      PD.QtyMoved,      PD.[Status],
      	PD.DropID,      	 PD.Loc,      	      PD.ID,      	   PD.PackKey,
      	PD.UpdateSource,   PD.CartonGroup,     PD.CartonType,
      	PD.ToLoc,      	 PD.DoReplenish,     PD.ReplenishZone,
      	PD.DoCartonize,    PD.PickMethod,      @c_Wavekey,
      	PD.EffectiveDate,  PD.AddDate,      	PD.AddWho,
      	PD.EditDate,       PD.EditWho,      	PD.TrafficCop,
      	PD.ArchiveCop,     PD.OptimizeCop,     PD.ShipFlag,
      	PD.PickSlipNo,     PD.TaskDetailKey,   PD.TaskManagerReasonKey,
      	PD.Notes,      	 PD.MoveRefKey,				 PD.Channel_ID
      FROM WAVEDETAIL WD (NOLOCK) 
      JOIN PICKDETAIL PD WITH (NOLOCK) ON WD.Orderkey = PD.Orderkey
      WHERE WD.Wavekey = @c_Wavekey
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38150     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert PickDetail_WIP Table (ispWAVPK01)' 
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END      
   END
   
   IF @n_debug = 1
      PRINT '@c_DispatchPiecePickMethod ' + @c_DispatchPiecePickMethod
   
   -- Traditional & Skip Hop full case pre-cartonize
   IF @n_continue IN(1,2) AND ISNULL(@c_DispatchPiecePickMethod,'') IN('T','S') --NJOW05
   BEGIN   	    	
   	  IF @n_debug = 1 
   	     PRINT '------------Full Case Precartonization----------'
   	     
      DECLARE cur_PICKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT TP.Loadkey,
                TP.Storerkey, 
                TP.Sku, 
                SUM(TP.Qty), 
                TP.UCCNo,
                TP.StdCube,
                TP.StdGrossWgt
         FROM #TMP_PICKDETAIL TP
         WHERE TP.UOM = '2' 
         GROUP BY TP.Loadkey,
                  TP.Storerkey, 
                  TP.Sku,
                  TP.UCCNo,
                  TP.StdCube,
                  TP.StdGrossWgt
         ORDER BY TP.Loadkey, TP.Sku         
                  
      OPEN cur_PICKDET  
      
      FETCH NEXT FROM cur_PICKDET INTO @c_Loadkey, @c_Storerkey, @c_Sku, @n_Qty, @c_UCCNo, @n_StdCube, @n_StdGrossWgt

      SET @c_PrevLoadkey = ''
      SET @c_SourceType = 'FULLCASE'
      SET @c_Pickslipno = ''
      SET @c_LabelNo = ''
      SET @c_CartonType = 'CTN'
      WHILE @@FETCH_STATUS = 0  
      BEGIN      	 
      	 IF @c_PrevLoadkey <> @c_Loadkey
      	 BEGIN
      	 	  --Create pickslip
      	 	  GOTO CREATE_PICKSLIP
      	 	  RTN_CREATE_PICKSLIP_FC:
      	 	  --Create Packheader
      	 	  GOTO CREATE_PACKHEADER
      	 	  RTN_CREATE_PACKHEADER_FC:      	 	        	 	        	 	        	 	  
      	 END     
      	 
      	 --Create label no
      	 GOTO CREATE_LABELNO
      	 RTN_CREATE_LABELNO_FC:
      	 
      	 --Create packdetail
      	 GOTO CREATE_PACKDETAIL
      	 RTN_CREATE_PACKDETAIL_FC:
      	 
   	     IF @n_debug = 1 
   	     BEGIN
   	        PRINT '@c_Loadkey:' + RTRIM(@c_Loadkey) + ' @c_Storerkey:' + RTRIM(@c_Storerkey) + ' @c_Sku:' + RTRIM(@c_SKU) 
   	            + ' @n_Qty:' + RTRIM(CAST(@n_Qty AS NVARCHAR)) + ' @c_UCCNo:' + RTRIM(@c_UCCNo) 
   	        PRINT '@c_Pickslipno:' + RTRIM(@c_Pickslipno) + ' @c_Labelno:' 
   	     END

      	 --Update labelno to pickdetail
      	 DECLARE cur_Update_PickDetail_Wip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      	 SELECT PickDetailKey 
      	 FROM #PickDetail_WIP (NOLOCK)
      	 JOIN WAVEDETAIL WD (NOLOCK) ON #PickDetail_WIP.Orderkey = WD.Orderkey   --NJOW03
      	 JOIN LOADPLANDETAIL LD (NOLOCK) ON #PickDetail_WIP.Orderkey = LD.Orderkey  --NJOW03
      	 WHERE WD.Wavekey = @c_Wavekey
      	 AND LD.Loadkey = @c_Loadkey
      	 AND #PickDetail_WIP.DropId = @c_UCCNo
      	 AND #PickDetail_WIP.Storerkey = @c_Storerkey
      	 AND #PickDetail_WIP.Sku = @c_Sku      	 	  

          OPEN cur_Update_PickDetail_Wip 
          FETCH NEXT FROM cur_Update_PickDetail_Wip INTO @c_WIP_PickDetailKey
          WHILE @@FETCH_STATUS = 0 
          BEGIN
      	    UPDATE #PickDetail_WIP --WITH (ROWLOCK)
      	    SET CaseId = @c_Labelno, 
      	        EditDate = GETDATE(), 
      	        TrafficCop = NULL
      	    WHERE PickDetailKey = @c_WIP_PickDetailKey
      	    
             SET @n_err = @@ERROR
             IF @n_err <> 0
             BEGIN
                SELECT @n_continue = 3  
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38160     
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table (ispWAVPK01)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
                GOTO QUIT_SP
             END      	    
          	
          	 FETCH NEXT FROM cur_Update_PickDetail_Wip INTO @c_WIP_PickDetailKey 
          END
          CLOSE cur_Update_PickDetail_Wip 
          DEALLOCATE cur_Update_PickDetail_Wip        	 
      	 
      	 SET @c_PrevLoadkey = @c_Loadkey
      	   
         FETCH NEXT FROM cur_PICKDET INTO @c_Loadkey, @c_Storerkey, @c_Sku, @n_Qty, @c_UCCNo, @n_StdCube, @n_StdGrossWgt
      END
      CLOSE cur_PICKDET  
      DEALLOCATE cur_PICKDET                                   
   END
   
   -- Traditional & HUB & Skip Hop Conso case or loose pre-cartonize for Assortment (prepackflag 1,2,3)
   IF @n_continue IN(1,2)
   BEGIN   	        
   	  IF @n_debug = 1 
   	     PRINT '------------Conso Case Precartonization BOM(Assortment)----------'

      IF @c_SortMode = 'S2' --NJOW03
      BEGIN
      	 SET @cur_PICKDET_BOM = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TP.Loadkey,
                   TP.CartonGroup, 
                   TP.PrePackGroupCode, --NJOW01
                   TP.Assortment,
                   --TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   0 AS AssortmentCube,
                   TP.Lottable01_BU --NJOW02
            FROM #TMP_PICKDETAIL TP
            --JOIN BILLOFMATERIAL BOM (NOLOCK) ON TP.Assortment = BOM.Notes
            --JOIN SKU (NOLOCK) ON BOM.Storerkey = SKU.Storerkey AND BOM.Sku = SKU.Sku
            WHERE (TP.UOM <> '2'
                   OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
            AND TP.PrePackFlag IN ('1','2','3')
            --AND TP.CubingIndicator = '51' 
            GROUP BY TP.Loadkey,
                   TP.CartonGroup, 
                   TP.PrePackGroupCode, --NJOW01
                   TP.Assortment,
                   --TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   TP.Lottable01_BU --NJOW02                
                   --CONVERT(DECIMAL(16,6),SKU.StdCube) 
             ORDER BY TP.Loadkey, MIN(TP.Sku), TP.Lottable01_BU, TP.PrePackFlag, TP.PrePackGroupCode, TP.Assortment, TP.CartonGroup, TP.MaxCartonUnits
                      --TP.Lottable01_BU --NJOW02
      END
      ELSE
      BEGIN --S1
      	 SET @cur_PICKDET_BOM = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TP.Loadkey,
                   TP.CartonGroup, 
                   TP.PrePackGroupCode, --NJOW01
                   TP.Assortment,
                   --TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   0 AS AssortmentCube,
                   TP.Lottable01_BU --NJOW02
            FROM #TMP_PICKDETAIL TP
            --JOIN BILLOFMATERIAL BOM (NOLOCK) ON TP.Assortment = BOM.Notes
            --JOIN SKU (NOLOCK) ON BOM.Storerkey = SKU.Storerkey AND BOM.Sku = SKU.Sku
            WHERE (TP.UOM <> '2'
                   OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
            AND TP.PrePackFlag IN ('1','2','3')
            --AND TP.CubingIndicator = '51' 
            GROUP BY TP.Loadkey,
                   TP.CartonGroup, 
                   TP.PrePackGroupCode, --NJOW01
                   TP.Assortment,
                   --TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   TP.Lottable01_BU --NJOW02                
                   --CONVERT(DECIMAL(16,6),SKU.StdCube) 
             ORDER BY TP.Loadkey, MIN(TP.Measurement), MIN(TP.Sku), TP.Lottable01_BU, TP.PrePackFlag, TP.PrePackGroupCode, TP.Assortment, TP.CartonGroup, TP.MaxCartonUnits
                      --TP.Lottable01_BU --NJOW02
      END
                   

      OPEN @cur_PICKDET_BOM  
      
      FETCH NEXT FROM @cur_PICKDET_BOM INTO @c_Loadkey, @c_CartonGroup, @c_PrePackGroupCode, @c_Assortment, @c_PrePackFlag, @n_MaxCartonUnits, @n_AssortmentCube,                                           
                                           @c_Lottable01_BU --NJOW02                                        

      SET @c_PrevLoadkey = ''
      SET @c_PrevPrePackFlag = ''
      SET @c_PrevCartonGroup = ''
      SET @n_PrevMaxCartonUnits = 0
      SET @c_PrevPrePackGroupCode = ''
      SET @c_PrevAssortment = ''
      SET @c_SourceType = 'CONSOCASE_BOM'
      SET @c_Pickslipno = ''
      SET @c_LabelNo = ''
      SET @c_UCCNo = ''
      SET @c_NewCarton = 'Y'
      SET @c_CartonType = ''
      SET @c_PrevLottable01_BU = '' --NJOW02

      WHILE @@FETCH_STATUS = 0  
      BEGIN      	       	 
      	 IF @c_PrevLoadkey <> @c_Loadkey
      	 BEGIN
      	 	  --Create pickslip
      	 	  GOTO CREATE_PICKSLIP
      	 	  RTN_CREATE_PICKSLIP_CCBOM:
      	 	  --Create Packheader
      	 	  GOTO CREATE_PACKHEADER
      	 	  RTN_CREATE_PACKHEADER_CCBOM:      	 	        	 	        	 	        	 	  
      	 END     
      	       	
      	 IF @c_PrevLoadkey <> @c_Loadkey OR @c_PrevPrePackFlag <> @c_PrePackFlag 
      	    OR @c_PrevCartonGroup <> @c_CartonGroup OR @n_PrevMaxCartonUnits <> @n_MaxCartonUnits
      	    OR ((@c_PrevPrePackGroupCode <> @c_PrePackGroupCode OR @c_PrevAssortment <> @c_Assortment) AND @c_PrePackFlag = '2') --NJOW01
      	    OR @c_PrevLottable01_BU <> @c_Lottable01_BU --NJOW02
      	 BEGIN
      	 	  SET @c_NewCarton = 'Y'
      	 END   
      	       	       	 
      	 DELETE FROM #TMP_ASSORTMENTDETAIL
	    	 
	    	 --retrieve component detail for the assortment of certain prepackflag, cartontype and maxcartonunits. and BU --NJOW02
         INSERT INTO #TMP_ASSORTMENTDETAIL (Storerkey, Sku, NbrUnitsInPpacks, AssortmentQty, StdGrossWgt, StdCube, UnitPerQty) 
	    	 SELECT TP.Storerkey, TP.Sku, TP.NbrUnitsInPpacks,
	    	        (SUM(TP.Qty) / TP.NbrUnitsInPpacks) AS AssortmentQty, --number of assorment -- IN00388803
	    	        CONVERT(DECIMAL(15,4), TP.StdGrossWgt) AS StdGrossWgt,
	    	        CONVERT(DECIMAL(16,6), TP.StdCube) AS StdCube,
	    	        TP.UnitPerQty
         FROM #TMP_PICKDETAIL TP 
         WHERE TP.Loadkey = @c_Loadkey
         AND (TP.UOM <> '2'
              OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
         AND TP.PrePackGroupCode = @c_PrePackGroupCode --NJOW01
         AND TP.Assortment = @c_Assortment         
         AND TP.CartonGroup = @c_CartonGroup
         --AND TP.CubingIndicator = @c_CubingIndicator
         AND TP.PrePackFlag = @c_PrePackFlag
         AND TP.MaxCartonUnits = @n_MaxCartonUnits
         AND TP.Lottable01_BU = @c_Lottable01_BU --NJOW02
         GROUP BY TP.Storerkey, TP.Sku, TP.NbrUnitsInPpacks, CONVERT(DECIMAL(15,4), TP.StdGrossWgt), CONVERT(DECIMAL(16,6), TP.StdCube), TP.UnitPerQty

         IF EXISTS (SELECT 1 FROM #TMP_ASSORTMENTDETAIL AD
                    HAVING COUNT(DISTINCT AD.AssortmentQty) > 1)
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38170     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Component sku order qty of PrePackGropCode '''+ RTRIM(@c_PrePackGroupCode) + ''' allotment '''+ RTRIM(@c_Assortment) + ''' is not tally by prepack flag, carton type, maxcartonunits (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           

            GOTO QUIT_SP 
         END                    

      	 --Calculate assortment cube from componentsku
      	 IF ISNULL(@n_AssortmentCube,0) = 0
      	 BEGIN
      	    SELECT @n_AssortmentCube = SUM(NbrUnitsInPpacks * StdCube)
      	    FROM #TMP_ASSORTMENTDETAIL       	    
      	 END
         
         SELECT TOP 1 @n_AssortmentQty = AssortmentQty -- all componet sku of the assortment should have same assortmentqty
         FROM #TMP_ASSORTMENTDETAIL
         
         SELECT @n_TotUnitPerAssortment = SUM(NbrUnitsInPpacks * UnitPerQty) --NJOW01 number of qty per assorment * number of unit per qty
    	   FROM #TMP_ASSORTMENTDETAIL       	    
                                            	                        
   	     IF @n_debug = 1 
   	     BEGIN
   	     	  PRINT '------------------------'
   	        PRINT '@c_Loadkey:' + RTRIM(@c_Loadkey) + ' @c_CartonGroup:' + RTRIM(@c_CartonGroup) + ' @c_Assortment:' + RTRIM(@c_Assortment) + ' @c_CubingIndicator:' + RTRIM(@c_CubingIndicator) + ' @c_PrepackFlag:' + RTRIM(@c_Prepackflag)
   	        PRINT '@c_MaxcartonUnits:' + RTRIM(CAST(@n_MaxCartonUnits AS NVARCHAR)) + ' @n_AssortmentCube:' + RTRIM(CAST(@n_AssortmentCube AS NVARCHAR)) + ' @c_Pickslipno:' + RTRIM(@c_Pickslipno) 
   	        PRINT '@n_AssortmentQty:' + RTRIM(CAST(@n_AssortmentQty AS NVARCHAR)) + ' @n_TotUnitPerAssortment:' + RTRIM(CAST(@n_TotUnitPerAssortment AS NVARCHAR))
   	        SELECT * FROM #TMP_ASSORTMENTDETAIL
   	     END
         
         IF @c_PrePackFlag = '1' -- 1 assortment 1 bom qty into one carton
         BEGIN        	  
         	WHILE @n_AssortmentQty > 0
         	BEGIN
         	   SET @c_NewCarton = 'Y'
               SET @n_TotalCubeRequire = @n_AssortmentCube
            
               IF @c_NewCarton = 'Y'
               BEGIN
         	      GOTO GET_CARTON
         	      RTN_GET_CARTON_CCBOM_PP1:
         	      SET @c_NewCarton = 'N'
         	   END
         	  
         	   IF @n_debug = 1
         	      PRINT '1 BAL @n_AssortmentQty:' + RTRIM(CAST(@n_AssortmentQty AS NVARCHAR)) + ' @c_Labelno:' + RTRIM(@c_Labelno) 

               DECLARE CUR_COMSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TA.Storerkey, TA.Sku, TA.NbrUnitsInPpacks, TA.StdGrossWgt   
               FROM #TMP_ASSORTMENTDETAIL TA
              
               OPEN CUR_COMSKU  
              
               FETCH NEXT FROM CUR_COMSKU INTO @c_Storerkey, @c_Sku, @n_Qty, @n_StdGrossWgt
              
               WHILE @@FETCH_STATUS <> -1  
               BEGIN      
              	   IF @n_debug = 1  	 
              	   BEGIN
              	      PRINT '1 INS COMP: @c_Sku:' + RTRIM(@c_Sku) + ' @n_Qty:' + RTRIM(CAST(@n_Qty AS NVARCHAR))
              	   END
              	    
      	         --Create packdetail
      	         GOTO CREATE_PACKDETAIL
      	         RTN_CREATE_PACKDETAIL_CCBOM_PP1:

   	             --Update labelno to pickdetail caseid
    	            GOTO UPDATE_PICKDETAIL_LABELNO
    	            RTN_UPDATE_PICKDETAIL_LABELNO_CCBOM_PP1:
         	                	    
                  FETCH NEXT FROM CUR_COMSKU INTO @c_Storerkey, @c_Sku, @n_Qty, @n_StdGrossWgt
         	    END
                CLOSE CUR_COMSKU  
                DEALLOCATE CUR_COMSKU                                   
         	    
         	    SET @n_AssortmentQty = @n_AssortmentQty - 1
         	 END         	  
         END
         ELSE IF @c_PrePackFlag IN('2','3') -- 2 = 1 assortment multiple bom qty into one carton. 3 = multi assortment multiple bom qty into one carton
         BEGIN
         	  SET @n_TotalCubeRequire = @n_AssortmentQty * @n_AssortmentCube  --use to determine best fit carton size
         	  
         	  --Pack Assorment to carton
         	  WHILE @n_AssortmentQty > 0 
         	  BEGIN         	  	 
               IF @c_NewCarton = 'Y'
               BEGIN
         	        GOTO GET_CARTON  --Get new label no, @n_BalCartonCube=cartoncube and @n_BalCartonQty=maxcartonunits
         	        RTN_GET_CARTON_CCBOM_PP23:
         	        SET @c_NewCarton = 'N'
         	     END
         	     
         	     IF ISNULL(@n_MaxCartonUnits,0) > 0 --NJOW01
         	     	  SET @n_NoOfAssortCanFit = FLOOR(@n_MaxCartonUnits / @n_TotUnitPerAssortment)
         	     ELSE
      	  	 	    SET @n_NoOfAssortCanFit = FLOOR(@n_BalCartonCube / @n_AssortmentCube)
         	  	 
         	  	    
         	  	 --IF @n_NoOfAssortCanFit > @n_BalCartonQty --cannot greater than max carton units if defined from orderdetail
         	  	 --   SET @n_NoOfAssortCanFit = @n_BalCartonQty
         	  	       
         	  	 IF @n_NoOfAssortCanFit > @n_AssortmentQty
         	  	    SET @n_NoOfAssortCanFit = @n_AssortmentQty         	  	    
                
               IF @n_debug = 1
               BEGIN
               	  PRINT '23 @c_Labelno:' + RTRIM(@c_Labelno)  
      	          PRINT '23 BAL @n_AssortmentQty:' + RTRIM(CAST(@n_AssortmentQty AS NVARCHAR)) + ' @n_NoOfAssortCanFit:' + RTRIM(CAST(@n_NoOfAssortCanFit AS NVARCHAR))
      	          PRINT '23 BAL @n_BalCartonCube:' + RTRIM(CAST(@n_BalCartonCube AS NVARCHAR)) + ' @n_BalCartonQty:' + RTRIM(CAST(@n_BalCartonQty AS NVARCHAR))
      	       END
         	  	    
         	  	 IF @n_NoOfAssortCanFit > 0
         	  	 BEGIN
         	  	    SET @n_TotalCubeRequire = @n_TotalCubeRequire - (@n_NoOfAssortCanFit * @n_AssortmentCube)
         	  	    SET @n_AssortmentQty = @n_AssortmentQty - @n_NoOfAssortCanFit
         	  	    SET @n_BalCartonCube = @n_BalCartonCube - (@n_NoOfAssortCanFit * @n_AssortmentCube)
         	  	    --SET @n_BalCartonQty = @n_BalCartonQty - @n_NoOfAssortCanFit
         	  	    SET @n_BalCartonQty = @n_BalCartonQty - (@n_NoOfAssortCanFit * @n_TotUnitPerAssortment)

            	    IF @n_AssortmentQty > 0
            	     SET @c_NewCarton = 'Y'
         	  	    
         	  	    --pack component sku of the assortment into carton
                  DECLARE CUR_COMSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT TA.Storerkey, TA.Sku, TA.NbrUnitsInPpacks, TA.StdGrossWgt   
                     FROM #TMP_ASSORTMENTDETAIL TA
                  
                  OPEN CUR_COMSKU  
                  
                  FETCH NEXT FROM CUR_COMSKU INTO @c_Storerkey, @c_Sku, @n_Qty, @n_StdGrossWgt
                  
                  WHILE @@FETCH_STATUS <> -1  
                  BEGIN                	  
                  	  SET @n_Qty = @n_Qty * @n_NoOfAssortCanFit       	 

              	     IF @n_debug = 1  	 
              	     BEGIN
              	        PRINT '23 INS COMP: @c_Sku:' + RTRIM(@c_Sku) + ' @n_Qty:' + RTRIM(CAST(@n_Qty AS NVARCHAR)) 
              	     END
              	     
      	             --Create packdetail
      	             GOTO CREATE_PACKDETAIL
      	             RTN_CREATE_PACKDETAIL_CCBOM_PP23:
      	             
      	             --Update labelno to pickdetail caseid
      	             GOTO UPDATE_PICKDETAIL_LABELNO
      	             RTN_UPDATE_PICKDETAIL_LABELNO_CCBOM_PP23:
         	                   	    
                     FETCH NEXT FROM CUR_COMSKU INTO @c_Storerkey, @c_Sku, @n_Qty, @n_StdGrossWgt
         	        END
                  CLOSE CUR_COMSKU  
                  DEALLOCATE CUR_COMSKU                   
               END                
               ELSE
               BEGIN
                  SET @c_NewCarton = 'Y'
               END                                                                     	  	 
         	  END         	  
         END
                          	       	 
      	 SET @c_PrevLoadkey = @c_Loadkey
      	 SET @c_PrevPrePackFlag = @c_PrePackFlag 
      	 SET @c_PrevCartonGroup = @c_CartonGroup 
      	 SET @n_PrevMaxCartonUnits = @n_MaxCartonUnits
      	 SET @c_PrevAssortment = @c_Assortment
      	 SET @c_PrevPrePackGroupCode = @c_PrePackGroupCode
      	 SET @c_PrevLottable01_BU = @c_Lottable01_BU --NJOW02
      	   
         FETCH NEXT FROM @cur_PICKDET_BOM INTO @c_Loadkey, @c_CartonGroup, @c_PrePackGroupCode, @c_Assortment, @c_PrePackFlag, @n_MaxCartonUnits, @n_AssortmentCube,
                                              @c_Lottable01_BU --NJOW02
      END
      CLOSE @cur_PICKDET_BOM  
      DEALLOCATE @cur_PICKDET_BOM                                   
   END

   -- Traditional & HUB & Skip Hop Conso case or loose pre-cartonize for none-Assortment sku (prepackflag 0)
   IF @n_continue IN(1,2)
   BEGIN   	        
   	  IF @n_debug = 1 
   	     PRINT '------------Conso Case Precartonization Non-BOM(By SKU)----------'

   	  --retrieve the pickdetail group by criteria that can combine into a carton
   	  IF @c_SortMode = 'S2'  --NJOW03
   	  BEGIN
   	  	 SET @cur_PICKDET_SKU = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TP.Loadkey,
                   TP.CartonGroup, 
                   TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   CASE WHEN TP.CubingIndicator IN('62','64') THEN TP.Style ELSE '' END AS Style, --6
                   CASE WHEN TP.CubingIndicator = '64' THEN TP.Color ELSE '' END AS Color, --7
                   CASE WHEN TP.CubingIndicator = '61' THEN TP.Sku ELSE '' END AS Sku,  --8
                   TP.Lottable01_BU --NJOW02
            FROM #TMP_PICKDETAIL TP
            WHERE (TP.UOM <> '2'
                   OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
            AND TP.PrePackFlag = '0'
            AND TP.CubingIndicator IN('51','61','62','64')
            GROUP BY TP.Loadkey,
                   TP.CartonGroup, 
                   TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   CASE WHEN TP.CubingIndicator IN('62','64') THEN TP.Style ELSE '' END,
                   CASE WHEN TP.CubingIndicator = '64' THEN TP.Color ELSE '' END,
                   CASE WHEN TP.CubingIndicator = '61' THEN TP.Sku ELSE '' END,
                   TP.Lottable01_BU --NJOW02
             ORDER BY TP.Loadkey, MIN(TP.Sku), TP.Lottable01_BU, TP.CubingIndicator, 6, 7, 8, TP.CartonGroup, TP.MaxCartonUnits 
                      --TP.Lottable01_BU --NJOW02
      END
      ELSE
      BEGIN --S1
   	  	 SET @cur_PICKDET_SKU = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT TP.Loadkey,
                   TP.CartonGroup, 
                   TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   CASE WHEN TP.CubingIndicator IN('62','64') THEN TP.Style ELSE '' END AS Style, --6
                   CASE WHEN TP.CubingIndicator = '64' THEN TP.Color ELSE '' END AS Color, --7
                   CASE WHEN TP.CubingIndicator = '61' THEN TP.Sku ELSE '' END AS Sku,  --8
                   TP.Lottable01_BU --NJOW02
            FROM #TMP_PICKDETAIL TP
            WHERE (TP.UOM <> '2'
                   OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
            AND TP.PrePackFlag = '0'
            AND TP.CubingIndicator IN('51','61','62','64')
            GROUP BY TP.Loadkey,
                   TP.CartonGroup, 
                   TP.CubingIndicator,
                   TP.PrePackFlag,
                   TP.MaxCartonUnits,
                   CASE WHEN TP.CubingIndicator IN('62','64') THEN TP.Style ELSE '' END,
                   CASE WHEN TP.CubingIndicator = '64' THEN TP.Color ELSE '' END,
                   CASE WHEN TP.CubingIndicator = '61' THEN TP.Sku ELSE '' END,
                   TP.Lottable01_BU --NJOW02
             ORDER BY TP.Loadkey, MIN(TP.Measurement), MIN(TP.Sku), TP.Lottable01_BU, TP.CubingIndicator, 6, 7, 8, TP.CartonGroup, TP.MaxCartonUnits
                      --TP.Lottable01_BU --NJOW02
      END      
          
      OPEN @cur_PICKDET_SKU  
      
      FETCH NEXT FROM @cur_PICKDET_SKU INTO @c_Loadkey, @c_CartonGroup, @c_CubingIndicator, @c_PrePackFlag, @n_MaxCartonUnits, @c_Style, @c_Color, @c_Sku,
                                           @c_Lottable01_BU --NJOW02

      SET @c_PrevLoadkey = ''
      SET @c_PrevCubingIndicator = ''
      SET @c_PrevCartonGroup = ''
      SET @n_PrevMaxCartonUnits = 0
      SET @c_PrevStyle = ''
      SET @c_PrevColor = ''
      SET @c_PrevSku = ''
      SET @c_SourceType = 'CONSOCASE_SKU'
      SET @c_Pickslipno = ''
      SET @c_LabelNo = ''
      SET @c_UCCNo = ''
      SET @c_NewCarton = 'Y'
      SET @c_CartonType = ''
      SET @c_PrevLottable01_BU = '' --NJOW02
      
      WHILE @@FETCH_STATUS = 0  
      BEGIN      	       	 
      	 IF @c_PrevLoadkey <> @c_Loadkey
      	 BEGIN
      	 	  --Create pickslip
      	 	  GOTO CREATE_PICKSLIP
      	 	  RTN_CREATE_PICKSLIP_CCSKU:

      	 	  --Create Packheader
      	 	  GOTO CREATE_PACKHEADER
      	 	  RTN_CREATE_PACKHEADER_CCSKU:      	 	        	 	        	 	        	 	  
      	 END     
      	 --51 = multiple sku in one carton
      	 --61 = one sku in one carton
      	 --62 = one style in one carton
      	 --64 = one style & color in one carton
      	 IF @c_PrevLoadkey <> @c_Loadkey OR @c_PrevCubingIndicator <> @c_CubingIndicator
      	    OR @c_PrevCartonGroup <> @c_CartonGroup OR @n_PrevMaxCartonUnits <> @n_MaxCartonUnits
      	    OR (@c_PrevStyle <> @c_Style AND @c_CubingIndicator IN('62','64'))
      	    OR (@c_PrevColor <> @c_Color AND @c_CubingIndicator = '64') 
      	    OR (@c_PrevSku <> @c_Sku AND @c_CubingIndicator = '61') 
      	    OR @c_PrevLottable01_BU <> @c_Lottable01_BU --NJOW02
      	 BEGIN
      	 	  SET @c_NewCarton = 'Y'
      	 END   

   	     IF @n_debug = 1 
   	     BEGIN
   	     	  PRINT '------------------------'
   	        PRINT '@c_Loadkey:' + RTRIM(@c_Loadkey) + ' @c_CartonGroup:' + RTRIM(@c_CartonGroup) + ' @c_CubingIndicator:' 
   	            + RTRIM(@c_CubingIndicator) + ' @c_PrepackFlag:' + RTRIM(@c_Prepackflag)
   	        PRINT '@c_MaxcartonUnits:' + RTRIM(CAST(@n_MaxCartonUnits AS NVARCHAR)) + ' @c_Pickslipno:' + RTRIM(@c_Pickslipno) 
   	        PRINT '@c_Style:' + RTRIM(@c_Style) + ' @c_Color:' + RTRIM(@c_Color) + ' @c_Sku:' + RTRIM(@c_Sku)
   	     END
      	 
       	 DELETE FROM #TMP_PACKDET
	    	 
	    	 --retrieve candidate sku for the syle, color, sku of certain cubingindicator, cartontype and maxcartonunits. and BU --NJOW02
         INSERT INTO #TMP_PACKDET (Storerkey, Sku, Qty, StdCube, StdGrossWgt, UnitPerQty, Measurement) --NJOW03 
      	 SELECT TP.Storerkey, TP.Sku, 
	    	 SUM(TP.Qty) AS Qty, 
	    	 CONVERT(DECIMAL(16,6),TP.StdCube) AS StdCube,
	    	 CONVERT(DECIMAL(15,4),TP.StdGrossWgt) AS StdGrossWgt,
	    	 TP.UnitPerQty, --NJOW01
	    	 TP.Measurement --NJOW03
         FROM #TMP_PICKDETAIL TP 
         WHERE TP.Loadkey = @c_Loadkey
         AND (TP.UOM <> '2'
              OR (TP.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
         AND TP.CartonGroup = @c_CartonGroup
         AND TP.CubingIndicator = @c_CubingIndicator
         AND TP.PrePackFlag = @c_PrePackFlag
         AND TP.MaxCartonUnits = @n_MaxCartonUnits
         AND TP.Style = CASE WHEN @c_CubingIndicator IN('62','64') THEN @c_Style ELSE TP.Style END
         AND TP.Color = CASE WHEN @c_CubingIndicator = '64' THEN @c_Color ELSE TP.Color END
         AND TP.Sku = CASE WHEN @c_CubingIndicator = '61' THEN @c_Sku ELSE TP.Sku END
         AND TP.Lottable01_BU = @c_Lottable01_BU --NJOW02
         GROUP BY TP.Storerkey, TP.Sku, CONVERT(DECIMAL(16,6),TP.StdCube), CONVERT(DECIMAL(15,4),TP.StdGrossWgt), TP.UnitPerQty, 
                  TP.Measurement --NJOW03 
         
         SELECT @n_TotalCubeRequire = SUM(Qty * StdCube)
         FROM #TMP_PACKDET 

       	 IF @c_SortMode = 'S2'  --NJOW03
   	     BEGIN
   	     	  SET @CUR_PACKSKU = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT Storerkey, Sku, SUM(Qty), StdCube, StdGrossWgt, UnitPerQty
               FROM #TMP_PACKDET
               GROUP BY Storerkey, Sku, StdCube, StdGrossWgt, UnitPerQty
               ORDER BY Storerkey, Sku
   	     END
   	     ELSE  
   	     BEGIN
   	     	  SET @CUR_PACKSKU = 
            CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT TP.Storerkey, TP.Sku, SUM(TP.Qty), TP.StdCube, TP.StdGrossWgt, TP.UnitPerQty
               FROM #TMP_PACKDET TP
               GROUP BY TP.Storerkey, TP.Sku, TP.StdCube, TP.StdGrossWgt, TP.UnitPerQty, TP.Measurement
               ORDER BY TP.Storerkey, TP.Measurement, TP.Sku   	     
   	     END      

         OPEN @CUR_PACKSKU  
               
         FETCH NEXT FROM @CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_SkuQty, @n_StdCube, @n_StdGrossWgt, @n_UnitPerQty
               
         WHILE @@FETCH_STATUS <> -1  
         BEGIN             
         	  --Pack sku to carton   	  
            WHILE @n_SkuQty > 0 
            BEGIN         	  	 
               IF @c_NewCarton = 'Y'
               BEGIN
               	  --Fix recalculate current carton size to best fit before new carton (NJOW04)
               	  IF ISNULL(@n_cartonno,0) > 0 
               	  BEGIN
               	  	 SELECT @n_CartonCube_Tmp = 0, @c_CartonType_Tmp = '', @n_Findcube_tmp = 0
               	  	 
               	  	 SELECT @n_Findcube_tmp = SUM(CONVERT(DECIMAL(16,6),SKU.StdCube) * PD.Qty)
               	  	 FROM PACKDETAIL PD (NOLOCK)
               	  	 JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
               	  	 WHERE PD.Pickslipno = @c_Pickslipno
               	  	 AND PD.Cartonno = @n_Cartonno
               	  	 
                     SELECT TOP 1 @n_CartonCube_Tmp = CONVERT(DECIMAL(16,6),CZ.[Cube]), @c_CartonType_Tmp = CZ.Cartontype
                     FROM CARTONIZATION CZ (NOLOCK)
                     WHERE CZ.CartonizationGroup = @c_FindCartonGroup
                     AND CZ.[Cube] >= @n_Findcube_tmp
                     ORDER BY CZ.[Cube]       
                     
                     IF @c_CartonType <> @c_CartonType_Tmp AND @n_CartonCube > @n_CartonCube_Tmp  
                     BEGIN
                     	  UPDATE PACKINFO WITH (ROWLOCK)
                     	  SET CartonType = @c_CartonType_Tmp,      
                     	      Cube = @n_CartonCube_Tmp,
                     	      TrafficCop = NULL
                     	  WHERE Pickslipno = @c_Pickslipno
                     	  AND CartonNo = @n_CartonNo                         	      
                     END                     
               	  END

                  GOTO GET_CARTON  --Get new label no, @n_BalCartonCube=cartoncube and @n_BalCartonQty=maxcartonunits
                  RTN_GET_CARTON_CCSKU:
                  SET @c_NewCarton = 'N'
               END
            
         	     IF ISNULL(@n_MaxCartonUnits,0) > 0 --NJOW01
         	     	  SET @n_NoOfQtyCanFit = FLOOR(@n_MaxCartonUnits / @n_UnitPerQty)
         	     ELSE
      	     	    SET @n_NoOfQtyCanFit = FLOOR(@n_BalCartonCube / @n_StdCube)
            	             	
            	 --IF @n_NoOfQtyCanFit > @n_BalCartonQty --cannot greater than max carton units if defined from orderdetail
            	 --   SET @n_NoOfQtyCanFit = @n_BalCartonQty
            	    
            	 IF @n_NoOfQtyCanFit > @n_SkuQty
            	    SET @n_NoOfQtyCanFit = @n_SkuQty
            	  
               IF @n_debug = 1
               BEGIN
               	  PRINT '@c_Labelno:' + RTRIM(@c_Labelno) +  + ' @n_StdCube:' + RTRIM(CAST(@n_StdCube AS NVARCHAR))
      	          PRINT 'BAL @n_SkuQty:' + RTRIM(CAST(@n_SkuQty AS NVARCHAR)) + ' @n_NoOfQtyCanFit:' + RTRIM(CAST(@n_NoOfQtyCanFit AS NVARCHAR))
      	          PRINT 'BAL @n_BalCartonCube:' + RTRIM(CAST(@n_BalCartonCube AS NVARCHAR)) + ' @n_BalCartonQty:' + RTRIM(CAST(@n_BalCartonQty AS NVARCHAR))
      	       END
            	    
            	 IF @n_NoOfQtyCanFit > 0
            	 BEGIN
            	 	  SET @n_Qty = @n_NoOfQtyCanFit
            	    SET @n_TotalCubeRequire = @n_TotalCubeRequire - (@n_NoOfQtyCanFit * @n_StdCube)
            	    SET @n_SkuQty = @n_SkuQty - @n_NoOfQtyCanFit
            	    SET @n_BalCartonCube = @n_BalCartonCube - (@n_NoOfQtyCanFit * @n_StdCube)
            	    SET @n_BalCartonQty = @n_BalCartonQty - @n_NoOfQtyCanFit
            	    
            	    IF @n_SkuQty > 0  --current carton already full but still have remain, so open new carton.
            	     SET @c_NewCarton = 'Y'

    	            GOTO CREATE_PACKDETAIL
      	          RTN_CREATE_PACKDETAIL_CCSKU:

  	              --IF @n_debug = 1
  	              --   PRINT '------------Non-BOM(Sku): Update Label No To Pickdetail---------' 

      	          --update label no to pickdetail
      	          SET @n_packqty = @n_NoOfQtyCanFit
                   DECLARE CUR_PICKDET_UPDATE2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PD.PickDetailKey, 
                            PD.Qty
                     FROM WAVEDETAIL WD (NOLOCK)
                     JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
                     JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                     JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber  --NJOW03
                     JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW02
                     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
                     LEFT JOIN CODELKUP CLK (NOLOCK) ON OD.Userdefine08 = CLK.Code AND CLK.ListName = 'CASAL' --NJOW02
                     WHERE WD.Wavekey = @c_Wavekey
                     AND (PD.UOM <> '2'
                          OR (PD.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H'))  
                     AND O.Loadkey = @c_Loadkey
                     AND ISNULL(OD.Userdefine08,'') = @c_CartonGroup
                     AND O.Userdefine05 = @c_CubingIndicator
                     AND O.SpecialHandling = @c_PrePackFlag
                     --AND CASE WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT) ELSE 0 END = @n_MaxCartonUnits
                     AND CASE WHEN CLK.Code IS NOT NULL THEN 1
                         WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT)
                         WHEN LEFT(OD.Userdefine08,1) = 'M' AND ISNUMERIC(SUBSTRING(OD.Userdefine08,2,10)) = 1 THEN CAST(SUBSTRING(OD.Userdefine08,2,10) AS INT)
                         ELSE 0 END = @n_MaxCartonUnits --NJOW02                      
                     AND PD.Storerkey = @c_Storerkey
                     --AND SKU.Style = CASE WHEN @c_CubingIndicator IN('62','64') THEN @c_Style ELSE SKU.Style END
                     --AND SKU.Color = CASE WHEN @c_CubingIndicator = '64' THEN @c_Color ELSE SKU.Color END
                     --AND PD.Sku = CASE WHEN @c_CubingIndicator = '61' THEN @c_Sku ELSE PD.Sku END
                     AND PD.Sku = @c_Sku
                     AND ISNULL(PD.Caseid,'') = ''
                     AND LA.Lottable01 = @c_Lottable01_BU --NJOW02
                     ORDER BY PD.PickDetailKey
            
                  OPEN CUR_PICKDET_UPDATE2  
                  
                  FETCH NEXT FROM CUR_PICKDET_UPDATE2 INTO @c_PickDetailKey, @n_PickQty
                  
                  WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0
                  BEGIN                	                                	             
                     IF @n_pickqty <= @n_packqty
                     BEGIN
                     	 UPDATE #PickDetail_WIP --WITH (ROWLOCK)  --NJOW03
                     	 SET CaseId = @c_labelno,
                     	     EditDate = GETDATE(), 
                     	     TrafficCop = NULL
                     	 WHERE PickDetailKey = @c_PickDetailKey
                     	 
                     	 SELECT @n_err = @@ERROR
                     	 IF @n_err <> 0
                     	 BEGIN
                     		 SELECT @n_continue = 3
                            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38210     
                     		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PickDetail_WIP Table Failed. (ispWAVPK01)' + ' ( ' 
                     		      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                            GOTO QUIT_SP 
			                END
			                SELECT @n_packqty = @n_packqty - @n_pickqty
    	               END
    	               ELSE
    	               BEGIN  -- pickqty > packqty
    	               	SELECT @n_splitqty = @n_pickqty - @n_packqty
	                     EXECUTE nspg_GetKey
                        'PICKDETAILKEY',
                        10,
                        @c_newpickdetailkey OUTPUT,
                        @b_success OUTPUT,
                        @n_err OUTPUT,
                        @c_errmsg OUTPUT
                        IF NOT @b_success = 1
                        BEGIN
                        	  SELECT @n_continue = 3
                        	  GOTO QUIT_SP
                        END

     	                 --IF @n_debug = 1
                       --  BEGIN
                       --  PRINT 'New @c_PickDetailKey:' + RTRIM(@c_PickDetailKey) + ' @c_NewPickdetailkey:' + RTRIM(@c_NewPickdetailkey) 
                       -- + ' @n_PickQty:' + RTRIM(CAST(@n_PickQty AS NVARCHAR)) + ' @n_PackQty:' + RTRIM(CAST(@n_PackQty AS NVARCHAR)) + 
                       -- ' @n_SplitQty:' + RTRIM(CAST(@n_SplitQty AS NVARCHAR))
                       --END
                         
                     	 INSERT #PickDetail_WIP --NJOW03
                               (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                                Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                                WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
                                Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID)
                        SELECT @c_newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                               Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '7' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                               DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                               WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID
                        FROM #PickDetail_WIP (NOLOCK) --NJOW03
                        WHERE PickDetailKey = @c_PickDetailKey
                     
                     	SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                        BEGIN
                           SELECT @n_continue = 3
                           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38220     
     	               	   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert PickDetail_WIP Table Failed. (ispWAVPK01)' + ' ( ' 
     	               	   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                       	   GOTO QUIT_SP
                       END
                     
                       UPDATE #PickDetail_WIP --WITH (ROWLOCK)  --NJOW03
                     	 SET CaseId = @c_labelno,
                     	     Qty = @n_packqty,
			               	  UOMQTY = CASE UOM WHEN '7' THEN @n_packqty ELSE UOMQty END, 
			               	  EditDate = GETDATE(),
                     	     TrafficCop = NULL                     	     
                     	 WHERE PickDetailKey = @c_PickDetailKey
                     	 
                     	 SELECT @n_err = @@ERROR
                     	 IF @n_err <> 0
                     	 BEGIN
                     		 SELECT @n_continue = 3
                            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38230     
                     		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update PickDetail_WIP Table Failed. (isp_AssignPackLabelToOrderByLoad)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                       	    GOTO QUIT_SP
			                END
                     
                        SELECT @n_packqty = 0
                     END
                     FETCH NEXT FROM CUR_PICKDET_UPDATE2 INTO @c_PickDetailKey, @n_PickQty
                  END
                  CLOSE CUR_PICKDET_UPDATE2  
                  DEALLOCATE CUR_PICKDET_UPDATE2                     
               END                
               ELSE
               BEGIN
                  SET @c_NewCarton = 'Y'
               END                                                                     	  	 
            END         	  
         	 
            FETCH NEXT FROM @CUR_PACKSKU INTO @c_Storerkey, @c_Sku, @n_SkuQty, @n_StdCube, @n_StdGrossWgt, @n_UnitPerQty
         END
         CLOSE @CUR_PACKSKU  
         DEALLOCATE @CUR_PACKSKU                                     
      	       	       	                                  	       	 
      	SET @c_PrevLoadkey = @c_Loadkey
      	SET @c_PrevCartonGroup = @c_CartonGroup 
      	SET @n_PrevMaxCartonUnits = @n_MaxCartonUnits
         SET @c_PrevCubingIndicator = @c_CubingIndicator
         SET @c_PrevColor = @c_Color
         SET @c_PrevStyle = @c_Style
         SET @c_PrevSku = @c_Sku          
         SET @c_PrevLottable01_BU = @c_Lottable01_BU --NJOW02
      	   
         FETCH NEXT FROM @cur_PICKDET_SKU INTO @c_Loadkey, @c_CartonGroup, @c_CubingIndicator, @c_PrePackFlag, @n_MaxCartonUnits, @c_Style, @c_Color, @c_Sku,
                                              @c_Lottable01_BU --NJOW02
      END
      CLOSE @cur_PICKDET_SKU  
      DEALLOCATE @cur_PICKDET_SKU                                   
   END
   
   DECLARE cur_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT PickDetailKey, CaseID, Qty, UOMQty, PickSlipNo 
   FROM #PickDetail_WIP WITH (NOLOCK) --NJOW03
   --WHERE WaveKey = @c_Wavekey 
   ORDER BY PickDetailKey 
   
   OPEN cur_PickDetailKey
   
   FETCH FROM cur_PickDetailKey INTO @c_WIP_PickDetailKey, @c_labelno, @n_packqty, @n_UOMQty, @c_PickslipNo
   
   WHILE @@FETCH_STATUS = 0
   BEGIN
   	IF EXISTS(SELECT 1 FROM PICKDETAIL WITH (NOLOCK) 
   	          WHERE PickDetailKey = @c_WIP_PickDetailKey)
   	BEGIN
   		UPDATE PICKDETAIL WITH (ROWLOCK) 
   		   SET CaseID = @c_labelno, 
   		       Qty = @n_PackQty, 
   		       UOMQty = @n_UOMQty, 
   		       PickSlipNo = @c_PickslipNo,
   		       WaveKey = @c_Wavekey,
   		       EditDate = GETDATE(),   	   		        	       
   		       TrafficCop = NULL
   		WHERE PickDetailKey = @c_WIP_PickDetailKey  
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38240     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK01)' + ' ( ' 
               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP 
			END   		
   	END
   	ELSE 
      BEGIN      	
      	INSERT INTO PICKDETAIL 
              (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
               Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
               DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
               WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, 
               Taskdetailkey, TaskManagerReasonkey, Notes )
         SELECT PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
               Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
               DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
               ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
               WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, 
               Taskdetailkey, TaskManagerReasonkey, Notes
         FROM #PickDetail_WIP AS wpd WITH (NOLOCK)  --NJOW03
         WHERE wpd.PickDetailKey = @c_WIP_PickDetailKey
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38250     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK01)' + ' ( ' 
               + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP 
			END         
      END
   
   	FETCH FROM cur_PickDetailKey INTO @c_WIP_PickDetailKey, @c_labelno, @n_packqty, @n_UOMQty, @c_PickslipNo 
   END
   
   CLOSE cur_PickDetailKey
   DEALLOCATE cur_PickDetailKey
      
         
   QUIT_SP:

   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDET')) >=0 
   BEGIN
      CLOSE cur_PICKDET           
      DEALLOCATE cur_PICKDET      
   END  
   /*
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDET_BOM')) >=0 
   BEGIN
      CLOSE cur_PICKDET_BOM           
      DEALLOCATE cur_PICKDET_BOM      
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','cur_PICKDET_SKU')) >=0 
   BEGIN
      CLOSE cur_PICKDET_SKU           
      DEALLOCATE cur_PICKDET_SKU
   END
   */  
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_COMSKU')) >=0 
   BEGIN
      CLOSE CUR_COMSKU           
      DEALLOCATE CUR_COMSKU
   END  
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PICKDET_UPDATE')) >=0 
   BEGIN
      CLOSE CUR_PICKDET_UPDATE           
      DEALLOCATE CUR_PICKDET_UPDATE
   END  
   /*
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PACKSKU')) >=0 
   BEGIN
      CLOSE CUR_PACKSKU           
      DEALLOCATE CUR_PACKSKU
   END
   */  
   IF (SELECT CURSOR_STATUS('LOCAL','CUR_PICKDET_UPDATE2')) >=0 
   BEGIN
      CLOSE CUR_PICKDET_UPDATE2
      DEALLOCATE CUR_PICKDET_UPDATE2
   END  
   
   IF OBJECT_ID('tempdb..#TMP_PICKDETAIL','u') IS NOT NULL
      DROP TABLE #TMP_PICKDETAIL;
   IF OBJECT_ID('tempdb..#TMP_ASSORTMENTDETAIL','u') IS NOT NULL
      DROP TABLE #TMP_ASSORTMENTDETAIL;
   IF OBJECT_ID('tempdb..#TMP_PACKDET','u') IS NOT NULL
      DROP TABLE #TMP_PACKDET;
   IF OBJECT_ID('tempdb..#PICKDETAIL_WIP','u') IS NOT NULL --NJOW03
      DROP TABLE #PICKDETAIL_WIP;

	 IF @n_Continue=3  -- Error Occured - Process AND Return
	 BEGIN
	    SELECT @b_Success = 0
	 	IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		ROLLBACK TRAN
	 	END
	 	ELSE
	 	BEGIN
	 		WHILE @@TRANCOUNT > @n_StartTCnt
	 		BEGIN
	 			COMMIT TRAN
	 		END
	 	END
	 	EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispWAVPK01'		
	 	RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
	 	--RAISERROR @nErr @cErrmsg
	 	RETURN
	 END
	 ELSE
	 BEGIN
	    SELECT @b_Success = 1
	 	WHILE @@TRANCOUNT > @n_StartTCnt
	 	BEGIN
	 		COMMIT TRAN
	 	END
	 	RETURN
	 END  
	 
	 -----------------Create Label No--------------
	 CREATE_LABELNO:
	 
	 EXEC isp_GLBL08 
         @c_PickSlipNo  
        ,1
        ,@c_LabelNo OUTPUT
	
   IF @c_SourceType = 'FULLCASE'
      GOTO RTN_CREATE_LABELNO_FC            
   ELSE 
      GOTO RTN_CREATE_LABELNO
 	 
	 -----------------Create Pickslip--------------	 
	 CREATE_PICKSLIP:
	 
   SET @c_PickSlipno = ''      
   SELECT @c_PickSlipno = PickheaderKey  
   FROM PickHeader (NOLOCK)  
   WHERE ExternOrderkey = @c_Loadkey
   AND ISNULL(OrderKey,'') = ''
                 
   -- Create Pickheader      
   IF ISNULL(@c_PickSlipno ,'') = ''  
   BEGIN  
      EXECUTE dbo.nspg_GetKey   
      'PICKSLIP',   9,   @c_Pickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38240     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Getkey(PICKSLIP) (ispWAVPK01)'
          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
        
      SELECT @c_Pickslipno = 'P'+@c_Pickslipno      
                 
      INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)  
                      VALUES (@c_Pickslipno , @c_LoadKey, '', '0', 'LB', '')              

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38250     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Pickheader Table (ispWAVPK01)' 
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
      
      DECLARE cur_Update_PickDetail_Wip2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT #PickDetail_WIP.PickDetailKey
      FROM LOADPLANDETAIL (NOLOCK)
      JOIN #PickDetail_WIP WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = #PickDetail_WIP.Orderkey  --NJOW03
      WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey 
      
      OPEN cur_Update_PickDetail_Wip2
      
      FETCH FROM cur_Update_PickDetail_Wip2 INTO @c_WIP_PickDetailKey
      
      WHILE @@FETCH_STATUS = 0
      BEGIN
         UPDATE #PickDetail_WIP --WITH (ROWLOCK)  --NJOW03
         SET    PickSlipNo = @c_PickSlipNo
               ,EditDate = GETDATE()   
               ,TrafficCop = NULL  
         WHERE PickDetailKey = @c_WIP_PickDetailKey      

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38260     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Pickdetail Table (ispWAVPK01)' 
            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END
      
      	FETCH FROM cur_Update_PickDetail_Wip2 INTO @c_WIP_PickDetailKey
      END
      
      CLOSE cur_Update_PickDetail_Wip2
      DEALLOCATE cur_Update_PickDetail_Wip2
      
      /*
      IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookUp WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)
      BEGIN
         INSERT INTO dbo.RefKeyLookUp (PickDetailKey, PickSlipNo, OrderKey, OrderLineNumber)
         SELECT PickdetailKey, PickSlipNo, OrderKey, OrderLineNumber 
         FROM PICKDETAIL (NOLOCK)  
         WHERE PickSlipNo = @c_PickSlipNo  
         
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0   
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38270     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert RefkeyLookUp Table (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END   
      END
      */
   END 
      
   -- Create PickingInfo with scanned in
   /*
   IF (SELECT COUNT(1) FROM PICKINGINFO(NOLOCK) WHERE Pickslipno = @c_Pickslipno) = 0
   BEGIN
      INSERT INTO PickingInfo (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                       VALUES (@c_Pickslipno ,GETDATE(),sUser_sName(), NULL)
   END
   */
   
   IF @c_SourceType = 'FULLCASE'
      GOTO RTN_CREATE_PICKSLIP_FC
   IF @c_SourceType = 'CONSOCASE_BOM'
      GOTO RTN_CREATE_PICKSLIP_CCBOM
   IF @c_SourceType = 'CONSOCASE_SKU'
      GOTO RTN_CREATE_PICKSLIP_CCSKU
         
	 -----------------Create Packheader--------------
	 CREATE_PACKHEADER:
	 
	 IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_Pickslipno)
	 BEGIN
      INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo)  
      SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo       
       FROM PICKHEADER PH (NOLOCK)  
        JOIN loadplandetail LPD (NOLOCK) ON LPD.Loadkey = PH.ExternOrderkey   -- tlting01  
        JOIN ORDERS O (NOLOCK) ON O.Orderkey = LPD.Orderkey  
        WHERE PH.Pickheaderkey = @c_PickSlipNo  
        AND ISNULL(PH.Orderkey,'') = ''  
         -- tlting02
            
             --SELECT TOP 1 O.Route, '', '', O.LoadKey, '',O.Storerkey, @c_PickSlipNo       
             --FROM  PICKHEADER PH (NOLOCK)      
             --JOIN  Orders O (NOLOCK) ON (PH.ExternOrderkey = O.Loadkey)      
             --WHERE PH.PickHeaderKey = @c_PickSlipNo
      
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38280     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packheader Table (ispWAVPK01)'
          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP
      END
	 END

   IF @c_SourceType = 'FULLCASE'
      GOTO RTN_CREATE_PACKHEADER_FC     
   IF @c_SourceType = 'CONSOCASE_BOM'
      GOTO RTN_CREATE_PACKHEADER_CCBOM
   IF @c_SourceType = 'CONSOCASE_SKU'
      GOTO RTN_CREATE_PACKHEADER_CCSKU

	 -----------------Create Packdetail--------------
	 CREATE_PACKDETAIL:
   
   -- CartonNo and LabelLineNo will be inserted by trigger    
   INSERT INTO PACKDETAIL     
      (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY, AddWho, AddDate, EditWho, EditDate, Refno)    
   VALUES     
      (@c_PickSlipNo, 0, @c_LabelNo, '00000', @c_StorerKey, @c_SKU,   
       @n_Qty, sUser_sName(), GETDATE(), sUser_sName(), GETDATE(), @c_UCCNo)
       
   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38290     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packdetail Table (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP
   END
   
   SET @n_CartonNo = 0
   SELECT TOP 1 @n_CartonNo = CartonNo
   FROM PACKDETAIL (NOLOCK)
   WHERE Pickslipno = @c_Pickslipno
   AND LabelNo = @c_LabelNo
   
   --Carete packinfo
   IF @n_CartonNo > 0 AND ISNULL(@c_CartonType,'') <> ''
   BEGIN   	     	          
   	  IF @c_SourceType = 'FULLCASE'
   	     SET @n_CartonCube = @n_Qty * @n_StdCube

      SET @n_CartonWeight = @n_Qty * @n_StdGrossWgt
   	  
   	  IF NOT EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_PickslipNo 
   	                 AND CartonNo = @n_CartonNo)
   	  BEGIN
   	  	 INSERT INTO PACKINFO (Pickslipno, CartonNo, CartonType, Cube, Weight, Qty)
   	  	 VALUES (@c_PickslipNo, @n_CartonNo, @c_CartonType, @n_CartonCube, @n_CartonWeight, @n_Qty)            
   	  	 
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38300     
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Insert Packinfo Table (ispWAVPK01)'
             + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
            GOTO QUIT_SP
         END   	  	 
   	  END
   	  ELSE
   	  BEGIN
   	  	 IF @c_SourceType <> 'FULLCASE' 
   	  	 BEGIN
   	        UPDATE PACKINFO WITH (ROWLOCK)
   	        SET Weight = Weight + @n_CartonWeight,
   	            Qty = Qty + @n_Qty	   	  
   	        WHERE Pickslipno = @c_PickslipNo 
   	        AND CartonNo = @n_CartonNo
            
            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38310     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Update Packinfo Table (ispWAVPK01)' 
               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
               GOTO QUIT_SP
            END   	 
         END 	    	     
   	  END
   END

   IF @c_SourceType = 'FULLCASE'
      GOTO RTN_CREATE_PACKDETAIL_FC        
   IF @c_SourceType = 'CONSOCASE_BOM' AND @c_PrePackFlag = '1'
      GOTO RTN_CREATE_PACKDETAIL_CCBOM_PP1
   IF @c_SourceType = 'CONSOCASE_BOM' AND @c_PrePackFlag IN('2','3')
      GOTO RTN_CREATE_PACKDETAIL_CCBOM_PP23
   IF @c_SourceType = 'CONSOCASE_SKU' 
      GOTO RTN_CREATE_PACKDETAIL_CCSKU
      
	 -----------------Get Carton (for loose carton only)--------------
   GET_CARTON:
   SET @c_FindCartonGroup = ''
   SET @c_CartonType = ''
   
   IF ISNULL(@c_CartonGroup,'') <> ''
   BEGIN
   	 SET @c_FindCartonGroup = @c_CartonGroup
   END
   ELSE
   BEGIN
   	  SELECT TOP 1 @c_FindCartonGroup = S.CartonGroup
   	  FROM STORER S (NOLOCK) 
   	  JOIN CARTONIZATION CZ (NOLOCK) ON (CZ.CartonizationGroup = S.CartonGroup)
   	  WHERE S.Storerkey = @c_Storerkey
   	  AND CZ.Cube <> 0

      IF ISNULL(@c_FindCartonGroup,'') = ''
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38320     
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
         +': Invalid Storer Cartonization Group or zero carton cube. Unable to open new carton (ispWAVPK01)' 
         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO QUIT_SP      	
      END
   END
   --get carton type and cube from storer cartonization setup
   
   -- find best fit carton by cube
   IF ISNULL(@n_MaxCartonUnits,0) = 0 --NJOW01
   BEGIN
      SELECT TOP 1 @n_CartonCube = CONVERT(DECIMAL(16,6),CZ.[Cube]), @c_CartonType = CZ.Cartontype
      FROM CARTONIZATION CZ (NOLOCK)
      WHERE CZ.CartonizationGroup = @c_FindCartonGroup
      AND CZ.[Cube] >= @n_TotalCubeRequire
      ORDER BY CZ.[Cube]
   END
   
   -- find larger carton
   IF ISNULL(@c_CartonType,'') = ''
   BEGIN
      SELECT TOP 1 @n_CartonCube = CONVERT(DECIMAL(16,6),CZ.[Cube]), @c_CartonType = CZ.Cartontype
      FROM CARTONIZATION CZ (NOLOCK)
      WHERE CZ.CartonizationGroup = @c_FindCartonGroup
      ORDER BY CZ.[Cube] DESC
      
      --Find the next large carton best fit the sku cube  --NJOW03
      IF @c_PrePackFlag IN('0','1','2','3') AND ISNULL(@c_CartonType,'') <> ''
      BEGIN
      	 SELECT @n_CartonCube_Tmp = 0, @c_CartonType_Tmp = '', @n_Stdcube_tmp = 0
      	 
      	 IF @c_PrePackFlag IN('1','2','3')
      	    SET @n_Stdcube_tmp = @n_AssortmentCube
      	 ELSE
      	    SET @n_Stdcube_tmp = @n_StdCube      	   
      	    
      	 SET @n_Findcube_tmp = FLOOR(@n_CartonCube / @n_Stdcube_tmp) * @n_Stdcube_tmp
      	  
         SELECT TOP 1 @n_CartonCube_Tmp = CONVERT(DECIMAL(16,6),CZ.[Cube]), @c_CartonType_Tmp = CZ.Cartontype
         FROM CARTONIZATION CZ (NOLOCK)
         WHERE CZ.CartonizationGroup = @c_FindCartonGroup
         AND CZ.[Cube] >= @n_Findcube_tmp
         ORDER BY CZ.[Cube]
         
         IF ISNULL(@c_CartonType_Tmp,'') <> ''
         BEGIN
         	  SET @c_CartonType = @c_CartonType_Tmp
         	  SET @n_CartonCube = @n_CartonCube_Tmp 
         END         
      END
   END
      
   IF ISNULL(@c_CartonType,'') = '' OR ISNULL(@n_CartonCube,0) = 0
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38330     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)
      +': Cartonization not setup or zero carton cube. Unable to open new carton (ispWAVPK01)' 
      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      	
   END
   
   IF @c_PrePackFlag IN ('1','2','3') AND @n_AssortmentCube > @n_CartonCube --Pack by BOM
      AND ISNULL(@n_MaxCartonUnits,0) = 0 --NJOW01 no need check cube if maxcartonunits have set
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38340     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Large carton cube unable to fit in a unit of Assortment ''' 
      + RTRIM(@c_Assortment) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      	
   END

   IF @c_PrePackFlag IN ('1','2','3') AND @n_TotUnitPerAssortment > @n_MaxCartonUnits 
      AND ISNULL(@n_MaxCartonUnits,0) > 0 --NJOW01 
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38342     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total units per assortment more than max units per carton on assortment ''' 
      + RTRIM(@c_Assortment) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      	
   END

   IF @c_PrePackFlag IN ('0') AND @n_UnitPerQty > @n_MaxCartonUnits 
      AND ISNULL(@n_MaxCartonUnits,0) > 0 --NJOW01 
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38344     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total units per sku more than max units per carton on sku ''' 
      + RTRIM(@c_Sku) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      	
   END

   IF @c_PrePackFlag = '0' AND @n_StdCube > @n_CartonCube --Pack by SKU
      AND ISNULL(@n_MaxCartonUnits,0) = 0 --NJOW01 
   BEGIN
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38350     
      SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Large carton cube unable to fit in a qty of Sku ''' 
      + RTRIM(@c_Sku) + ''' (ispWAVPK01)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
      GOTO QUIT_SP      	
   END
   
   IF @n_MaxCartonUnits > 0
      IF @c_PrePackFlag = '0'
         SET @n_BalCartonQty = @n_MaxCartonUnits / @n_UnitPerQty  --NJOW01 convert from component unit to qty for non-assortment
      ELSE
         SET @n_BalCartonQty = @n_MaxCartonUnits -- Get from order.IncoTerm. prepackflag 1,2,3 keep in component units
   ELSE 
      SET @n_BalCartonQty = 99999999  -- no define set to maximum

   SET @n_BalCartonCube = @n_CartonCube 

   GOTO CREATE_LABELNO
   RTN_CREATE_LABELNO:
      
   IF @c_PrePackFlag = '1'
      GOTO RTN_GET_CARTON_CCBOM_PP1
   IF @c_PrePackFlag IN('2','3')
      GOTO RTN_GET_CARTON_CCBOM_PP23
   IF @c_PrePackFlag = '0'
      GOTO RTN_GET_CARTON_CCSKU
   
   ------------Update labelno to pickdetail caseid for BOM(Assortment)-----------      
   UPDATE_PICKDETAIL_LABELNO:
         	             
   SET @n_packqty = @n_Qty
   DECLARE CUR_PICKDET_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.PickDetailKey, 
             PD.Qty
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON WD.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN #PickDetail_WIP PD (NOLOCK) ON O.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
      JOIN LOTATTRIBUTE LA (NOLOCK) ON PD.Lot = LA.Lot --NJOW02
      LEFT JOIN CODELKUP CLK (NOLOCK) ON OD.Userdefine08 = CLK.Code AND CLK.ListName = 'CASAL' --NJOW02
      WHERE WD.Wavekey = @c_Wavekey
      AND (PD.UOM <> '2'
          OR (PD.UOM = '2' AND ISNULL(@c_DispatchPiecePickMethod,'') = 'H')) --Hub will not have UOM 2 but just in case
      AND O.Loadkey = @c_Loadkey
      AND SUBSTRING(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) + 1 , LEN(OD.Userdefine03)) = @c_Assortment         
      AND ISNULL(OD.Userdefine08,'') = @c_CartonGroup
      AND LEFT(OD.Userdefine03, CHARINDEX('-',OD.Userdefine03) -1) = @c_PrePackGroupCode --NJOW01
      --AND O.Userdefine05 = @c_CubingIndicator
      AND O.SpecialHandling = @c_PrePackFlag
      --AND CASE WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT) ELSE 0 END = @n_MaxCartonUnits
      AND CASE WHEN CLK.Code IS NOT NULL THEN 1
          WHEN ISNUMERIC(O.IncoTerm) = 1 THEN CAST(O.IncoTerm AS INT)
          WHEN LEFT(OD.Userdefine08,1) = 'M' AND ISNUMERIC(SUBSTRING(OD.Userdefine08,2,10)) = 1 THEN CAST(SUBSTRING(OD.Userdefine08,2,10) AS INT)
          ELSE 0 END = @n_MaxCartonUnits --NJOW02                      
      AND PD.Storerkey = @c_Storerkey
      AND PD.Sku = @c_Sku
      AND ISNULL(PD.Caseid,'') = ''
      AND LA.Lottable01 = @c_Lottable01_BU --NJOW02
      ORDER BY PD.PickDetailKey
   
   OPEN CUR_PICKDET_UPDATE  
   
   FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickQty
   
   WHILE @@FETCH_STATUS <> -1 AND @n_packqty > 0 
   BEGIN                	                                	             
      IF @n_pickqty <= @n_packqty
      BEGIN
      	 UPDATE #PickDetail_WIP --WITH (ROWLOCK) --NJOW03
      	 SET CaseId = @c_labelno,
      	     TrafficCop = NULL
      	 WHERE PickDetailKey = @c_PickDetailKey
      	 
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
      		 SELECT @n_continue = 3
           SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38360     
      		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispWAVPK01)' 
      		 + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
           GOTO QUIT_SP 
		   	 END
		   	 SELECT @n_packqty = @n_packqty - @n_pickqty
      END
      ELSE
      BEGIN  -- pickqty > packqty
      	 SELECT @n_splitqty = @n_pickqty - @n_packqty
	       EXECUTE nspg_GetKey
         'PICKDETAILKEY',
         10,
         @c_newpickdetailkey OUTPUT,
         @b_success OUTPUT,
         @n_err OUTPUT,
         @c_errmsg OUTPUT
         IF NOT @b_success = 1
         BEGIN
         	  SELECT @n_continue = 3
         	  GOTO QUIT_SP
         END
      
      	 INSERT #PickDetail_WIP   --NJOW03
                (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                 Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                 DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                 ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                 WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID)
         SELECT @c_newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '7' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Taskdetailkey, TaskManagerReasonkey, Notes, Channel_ID
         FROM #PickDetail_WIP (NOLOCK)
         WHERE PickDetailKey = @c_PickDetailKey
      
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38370     
      	   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispWAVPK01)' + ' ( ' 
      	    + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
      
         UPDATE #PickDetail_WIP --WITH (ROWLOCK) --NJOW03
      	 SET CaseId = @c_labelno,
      	     Qty = @n_packqty,
		   	  UOMQTY = CASE UOM WHEN '7' THEN @n_packqty ELSE UOMQty END,
		   	  EditDate = GETDATE(), 
      	     TrafficCop = NULL
      	 WHERE PickDetailKey = @c_PickDetailKey
      	 SELECT @n_err = @@ERROR
      	 IF @n_err <> 0
      	 BEGIN
      		 SELECT @n_continue = 3
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 38380     
      		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (isp_AssignPackLabelToOrderByLoad)' 
      		  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
        	    GOTO QUIT_SP
		    END
      
         SELECT @n_packqty = 0
      END
      FETCH NEXT FROM CUR_PICKDET_UPDATE INTO @c_PickDetailKey, @n_PickQty
   END
   CLOSE CUR_PICKDET_UPDATE  
   DEALLOCATE CUR_PICKDET_UPDATE                

   IF @c_SourceType = 'CONSOCASE_BOM' AND @c_PrePackFlag = '1'
      GOTO RTN_UPDATE_PICKDETAIL_LABELNO_CCBOM_PP1
   IF @c_SourceType = 'CONSOCASE_BOM' AND @c_PrePackFlag IN('2','3')
      GOTO RTN_UPDATE_PICKDETAIL_LABELNO_CCBOM_PP23   
END

GO