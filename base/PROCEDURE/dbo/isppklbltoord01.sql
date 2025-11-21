SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc : ispPKLBLToOrd01                                        */
/* Creation Date: 20-Mar-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1363 UA HK - Assign pack label# to picketail            */
/*                                                                      */
/* Called By: ispPKLBLToOrd01 - Confirm pick                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver.  Purposes                                  */
/* 12/09/2019  WLChooi  1.1   WMS-10582 - Add new logic to skip         */
/*                            some validation (WL01)                    */
/* 17/10/2019  WLChooi  1.2   INC0897303 - New condition (WL02)         */
/************************************************************************/
CREATE PROC [dbo].[ispPKLBLToOrd01]
(@c_Pickslipno NVARCHAR(10),  
 @b_Success      int       OUTPUT,
 @n_err          int       OUTPUT,
 @c_errmsg       NVARCHAR(250) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON			
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue		      INT,
           @c_debug             NVARCHAR(1),
           @n_starttcnt         INT,
           @n_cnt               INT
   
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT, @b_success=0, @n_err=0,  @c_debug = '0'
   
   DECLARE @c_sku               NVARCHAR(20),
           @n_packqty           INT,
           @n_pickqty           INT,
           @n_splitqty          INT,
           @c_labelno           NVARCHAR(20),
           @c_pickdetailkey     NVARCHAR(10),
           @c_newpickdetailkey  NVARCHAR(10),
           @c_orderkey          NVARCHAR(10), 
           @c_RefNo2            NVARCHAR(30),
           @n_LabelNoLen        INT,
           @c_LabelNoPrefix00   NVARCHAR(2)
   
   --WL01 Start
   DECLARE @n_FoundRec                 INT,           
           @c_CLShort                  NVARCHAR(10),  
           @c_CLLong                   NVARCHAR(250),  
           @c_Facility                 NVARCHAR(5),   
           @c_AssignPackLabelToOrdCfg  NVARCHAR(30),  
           @c_storerkey                NVARCHAR(15),  
           @c_option1                  NVARCHAR(50),  
           @c_option2                  NVARCHAR(50),  
           @c_option3                  NVARCHAR(50),  
           @c_option4                  NVARCHAR(50),  
           @c_option5                  NVARCHAR(4000),
           @c_SQL                      NVARCHAR(4000),
           @c_SQLArgument              NVARCHAR(4000),
           @n_TotPickQty               INT,  
           @n_TotPackQty               INT,
           @c_loadkey                  NVARCHAR(10)  
   --WL01 End
              
   --Validation
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN   	
      SELECT TOP 1 @c_Orderkey = PACKHEADER.Orderkey, 
                   @n_LabelNoLen = LEN(LTRIM(RTRIM(PACKDETAIL.LabelNo))),
                   @c_LabelNoPrefix00 = LEFT(LTRIM(PACKDETAIL.LabelNo),2),
                   @c_loadkey = PACKHEADER.Loadkey --WL01
      FROM PACKHEADER (NOLOCK)
      JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
      WHERE PACKHEADER.Pickslipno = @c_Pickslipno
      ORDER BY PACKDETAIL.LabelNo DESC
      
      --WL01 Start
      --Do not validate REFNO2 when Pack Confirm if Country in Codelkup.Long
      IF ISNULL(@c_Orderkey,'') <> ''  
      BEGIN  
         SELECT @c_Storerkey = Storerkey,  
                @c_Facility = Facility  
         FROM ORDERS (NOLOCK)  
         WHERE Orderkey = @c_Orderkey  
      END  
      ELSE  
      BEGIN  
         SELECT TOP 1 @c_Storerkey = Storerkey,  
                      @c_Facility = Facility  
         FROM ORDERS (NOLOCK)  
         WHERE Loadkey = @c_Loadkey  
      END 

      EXECUTE nspGetRight   
      @c_facility,    
      @c_StorerKey,                
      '',                      
      'AssignPackLabelToOrdCfg', -- Configkey  
      @b_success    OUTPUT,  
      @c_AssignPackLabelToOrdCfg OUTPUT,  
      @n_err        OUTPUT,  
      @c_errmsg     OUTPUT,  
      @c_option1 OUTPUT, --ispPKLBLToOrd??  
      @c_option2 OUTPUT, --CaseID => Update Pickdetail.CaseID  
      @c_option3 OUTPUT, --FullLabelNo  
      @c_option4 OUTPUT, --skipstamped  
      @c_option5 OUTPUT  

      SELECT @c_CLShort = ISNULL(CL.Short,''),
             @c_CLLong  = ISNULL(CL.Long,'')
      FROM CODELKUP CL (NOLOCK)
      WHERE CL.Listname = 'CTNGETREF'
      AND CL.Storerkey = @c_Storerkey
      AND CL.Code = 'REFNO2'

      SELECT @n_FoundRec = COUNT(1)
      FROM ORDERS O (NOLOCK)
      WHERE  O.Orderkey = @c_Orderkey
      AND O.C_Country IN 
      (SELECT LTRIM(RTRIM(COLVALUE)) 
      FROM dbo.fnc_delimsplit (',',dbo.fnc_GetParamValueFromString(@c_CLShort, @c_CLLong, 'HK, MO')))
      AND O.Storerkey = @c_Storerkey
      --WL01 End
      
      SELECT P.Orderkey , P.Sku, LA.Lottable08 AS COO, SUM(P.Qty) AS Qty
      INTO #TMP_PICKDET
      FROM PICKDETAIL P (nolock) 
      JOIN LOTATTRIBUTE LA (NOLOCK) ON  P.Lot = LA.Lot
      WHERE P.Orderkey = @c_Orderkey 
      GROUP BY P.Orderkey, P.Sku, LA.Lottable08
      
      SELECT PKH.Orderkey, PKD.Sku ,PKD.Refno2 AS COO, SUM(PKD.Qty) AS Qty
      INTO #TMP_PACKDET
      FROM PACKHEADER PKH (NOLOCK)
      JOIN PACKDETAIL PKD (NOLOCK) ON PKH.Pickslipno = PKD.Pickslipno
      WHERE PKH.Pickslipno  = @c_Pickslipno 
      GROUP BY PKH.Orderkey, PKD.Sku, PKD.Refno2
      
      IF EXISTS (SELECT 1 
                 FROM #TMP_PICKDET PICK
                 LEFT JOIN #TMP_PACKDET PACK ON PICK.Orderkey = PACK.Orderkey AND PICK.Sku = PACK.Sku AND PICK.COO = PACK.COO
                 WHERE ISNULL(PICK.Qty, 0) <> ISNULL(PACK.Qty, 0))
      BEGIN
         --WL01 Start
         IF @n_FoundRec = 0 
         BEGIN
      		 SELECT @n_continue = 3
      		 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63310
      		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Packing COO qty not match with Order. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
         --WL01 End
      END                	 
   END  --validation    
   
   --For debug only
   --SELECT @c_Storerkey, @c_Facility, @c_CLShort, @c_CLLong, @n_FoundRec
   --GOTO QUIT_SP

   --WL01 Start
   --If C_Country in Codelkup.Long, follow standard logic to assign packdetail to pickdetail
   --Copy from isp_AssignPackLabelToOrderByLoad
   IF (@n_continue = 1 OR @n_continue = 2) AND (@n_FoundRec = 1)
   BEGIN
      IF @n_continue = 1 OR @n_continue = 2  
      BEGIN
         SET @n_TotPackQty = 0  
         SELECT @n_TotPackQty = SUM(PACKDETAIL.Qty)  
         FROM PACKDETAIL WITH (NOLOCK)  
         WHERE PickSlipNo = @c_PickSlipNo  
        
         IF ISNULL(RTRIM(@c_orderkey),'') = ''  
         BEGIN  
            SET @n_TotPickQty = 0  
            SELECT @n_TotPickQty = SUM(PICKDETAIL.Qty)  
            FROM LOADPLANDETAIL WITH (NOLOCK)  
            JOIN PICKDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey  
            WHERE LOADPLANDETAIL.Loadkey = @c_loadkey  
         END  
         ELSE  
         BEGIN  
            SET @n_TotPickQty = 0  
            SELECT @n_TotPickQty = SUM(PICKDETAIL.Qty)  
            FROM  PICKDETAIL WITH (NOLOCK)  
            WHERE PICKDETAIL.Orderkey = @c_orderkey  
         END  
        
         IF ISNULL(@n_TotPackQty, 0) <> ISNULL(@n_TotPickQty, 0)  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @n_err = 63311  
            SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total PackQty ('+ CAST(@n_TotPackQty AS VARCHAR) +  
                               ') vs PickQty ('+ CAST(@n_TotPickQty AS VARCHAR) +') Not Tally. (ispPKLBLToOrd01)'  
         END  
      END  

      -- Clear all the dropid(labelno) for re-assign in case of pack status reversal by manual and confirm pack again in future 
      IF ISNULL(@c_Option4,'') <> 'SKIPSTAMPED'
      BEGIN
         IF ISNULL(@c_orderkey,'') = ''   
         BEGIN  
            DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PICKDETAIL.Pickdetailkey  
            FROM LOADPLANDETAIL WITH (NOLOCK) INNER JOIN PICKDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey  
            WHERE LOADPLANDETAIL.Loadkey = @c_loadkey  
         END  
         ELSE  
         BEGIN  
            DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PICKDETAIL.Pickdetailkey  
            FROM  PICKDETAIL WITH (NOLOCK)  
            WHERE PICKDETAIL.Orderkey = @c_orderkey  
         END  

         OPEN PickDet_cur  
         
         FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
         
         WHILE @@FETCH_STATUS = 0 AND ( @n_continue = 1 OR @n_continue = 2 )  
         BEGIN  
            UPDATE PICKDETAIL WITH (ROWLOCK)  
            SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END   --(Wan01)  
               ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END   --(Wan01)  
               ,TrafficCop = NULL  
            WHERE PICKDETAIL.Pickdetailkey = @c_pickdetailkey  
            
            SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN  
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63312  
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            END  
  
            FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
         END  
         CLOSE PickDet_cur  
         DEALLOCATE PickDet_cur  
         SET @c_pickdetailkey = '' 
      END
      -- Clear all the dropid(labelno) for re-assign in case of pack status reversal by manual and confirm pack again in future

      IF ISNULL(@c_Option4,'') = 'SKIPSTAMPED' 
      BEGIN  
         DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,  --WL02
                PACKHEADER.Orderkey --NJOW02  
         FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
         INNER JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.ORDERKEY = PACKHEADER.ORDERKEY --WL02 
         WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
         AND NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)  
                         WHERE PD.Orderkey = PACKHEADER.Orderkey  
                         AND PD.Sku = PACKDETAIL.Sku   
                         AND PD.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PACKDETAIL.LabelNo ELSE PD.CaseID END  
                         AND PD.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PD.DropID ELSE PACKDETAIL.DropID END  --WL02
                         )  
         AND PACKHEADER.Orderkey <> ''  
         AND PACKHEADER.Orderkey IS NOT NULL 
         AND PACKDETAIL.DropID <> PICKDETAIL.DropID --WL02 
         UNION ALL   --NJOW07  
         SELECT DISTINCT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,  --WL02
                PACKHEADER.Orderkey --NJOW02  
         FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
         INNER JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PACKHEADER.LoadKey --WL02 
         INNER JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.Orderkey --WL02 
         WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
         AND NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)  
                         JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey  
                         WHERE LPD.Loadkey = PACKHEADER.Loadkey  
                         AND PD.Sku = PACKDETAIL.Sku   
                         AND PD.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PACKDETAIL.LabelNo ELSE PD.CaseID END  
                         AND PD.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PD.DropID ELSE PACKDETAIL.DropID END  --WL02
                         )  
         AND (PACKHEADER.Orderkey = '' OR PACKHEADER.Orderkey IS NULL)  
         AND  PACKDETAIL.DropID <> PD.DropID --WL02 
         ORDER BY 1, 3  
      END  
      ELSE 
      BEGIN      
         DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,  
                PACKHEADER.Orderkey --NJOW02  
         FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
         WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
         ORDER BY PACKDETAIL.Sku, PACKDETAIL.Labelno  
      END  

      OPEN CUR_PACKDET

      FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey --NJOW02  

      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @c_pickdetailkey = ''  

         WHILE @n_packqty > 0  
         BEGIN
            IF @c_OPtion3 <> 'FullLabelNo'  
            BEGIN  
               --NJOW01  
               IF LEN(LTRIM(RTRIM(@c_labelno))) > 18  
               BEGIN  
                  IF LEFT(LTRIM(@c_labelno),2) = '00'  
                  BEGIN  
                     SET @c_labelno = RIGHT(LTRIM(RTRIM(@c_labelno)),18)  
                  END  
                  --ELSE                                                      --SOS319000  
                  --SET @c_labelno = LEFT(LTRIM(RTRIM(@c_labelno)),18)  --SOS319000  
               END  
            END  
  
            SET @n_cnt = 0  
            SET @c_SQL = N'SELECT TOP 1 @n_cnt = 1'  
                       + ',@n_pickqty = PICKDETAIL.Qty'  
                       + ',@c_pickdetailkey = PICKDETAIL.Pickdetailkey'  
                       + ' FROM PICKDETAIL WITH (NOLOCK)'  
                       + CASE WHEN ISNULL(@c_orderkey,'')=''   
                              THEN ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey'   
                              ELSE ''   
                              END  
                       + CASE WHEN ISNULL(@c_orderkey,'')=''   
                              THEN ' WHERE LOADPLANDETAIL.Loadkey = @c_loadkey'   
                              ELSE ' WHERE PICKDETAIL.Orderkey = @c_orderkey'   
                              END  
                       + ' AND PICKDETAIL.Sku = @c_sku'  
                       + ' AND PICKDETAIL.storerkey = @c_storerkey'  -- (james01)
                       + CASE WHEN @c_Option2 = 'CaseID'   
                              THEN ' AND (PICKDETAIL.CaseID = '''' OR PICKDETAIL.CaseID IS NULL)'   
                              ELSE ' AND (PICKDETAIL.Dropid = '''' OR PICKDETAIL.Dropid IS NULL)'   
                              END  
                       + ' AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey'  
                       + ' ORDER BY PICKDETAIL.Pickdetailkey'  
            
            SET @c_SQLArgument = N'@n_cnt             INT            OUTPUT'  
                               + ',@n_pickqty         INT            OUTPUT'  
                               + ',@c_PickDetailKey   NVARCHAR(10)   OUTPUT'  
                               + ',@c_loadkey         NVARCHAR(10)'  
                               + ',@c_orderkey        NVARCHAR(10)'  
                               + ',@c_sku             NVARCHAR(20)'  
                               + ',@c_StorerKey       NVARCHAR(15)'  
            
            EXEC sp_executesql @c_SQL  
                  ,  @c_SQLArgument  
                  ,  @n_Cnt            OUTPUT  
                  ,  @n_pickqty        OUTPUT   
                  ,  @c_PickDetailKey  OUTPUT  
                  ,  @c_loadkey  
                  ,  @c_orderkey         
                  ,  @c_sku  
                  ,  @c_StorerKey  
            
            IF @n_cnt = 0  
            BREAK  
  
            IF @n_pickqty <= @n_packqty  
            BEGIN  
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE @c_labelno END   --(Wan01)  
                  ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN @c_labelno ELSE PICKDETAIL.CaseID END   --(Wan01)  
                  ,TrafficCop = NULL  
               WHERE Pickdetailkey = @c_pickdetailkey 
                
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63313  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
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
                  BREAK  
               END  
            
                INSERT PICKDETAIL  
                      (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                       Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,  
                       DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                       ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo   
                     , TaskDetailKey                                                --(Wan02)  
                      )  
               SELECT @c_newpickdetailkey  
                    , CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END                             --(Wan01)  
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                      Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,  
                      CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END                             --(Wan01)                              
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo  
                    , TaskDetailKey                                                --(Wan02)  
               FROM PICKDETAIL (NOLOCK)  
               WHERE PickdetailKey = @c_pickdetailkey  
            
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63314  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
            
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE @c_labelno END   --(Wan01)  
                  ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN @c_labelno ELSE PICKDETAIL.CaseID END   --(Wan01)  
                  ,Qty = @n_packqty  
                  ,UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END   
                  ,TrafficCop = NULL  
                WHERE Pickdetailkey = @c_pickdetailkey  
                SELECT @n_err = @@ERROR  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63315 
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
            
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0  
         FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey --NJOW02  
      END -- Cursor While  
      CLOSE CUR_PACKDET
      DEALLOCATE CUR_PACKDET 
   END --@n_FoundRec = 1
   --WL01 END

   IF (@n_continue = 1 OR @n_continue = 2) AND (@n_FoundRec = 0)
   --Update Pack label no to pickdetail dropid & caseid if not yet assign. it might partially assigned by RDT replenishment before.
   BEGIN
   	  --Extract packdetail and convert label no
     	SELECT PickslipNo,
   	       SKU, 
   	       Qty, 
   	       --CASE WHEN @n_LabelNoLen > 18 AND @c_LabelNoPrefix00 = '00' THEN 
   	       --     RIGHT(LTRIM(RTRIM(@c_labelno)),18) ELSE LabelNo END AS LabelNo, 
   	       Labelno,
   	       RefNo2,
   	       DropID
   	  INTO #TMP_PACKDETAIL
   	  FROM PACKDETAIL (NOLOCK)
   	  WHERE Pickslipno = @c_Pickslipno

   	  -- Remove invalid dropid
   	  /*
   	  DECLARE Pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   	     SELECT PICKDETAIL.Pickdetailkey
   	     FROM PICKDETAIL (NOLOCK)
   	     WHERE PICKDETAIL.Orderkey = @c_Orderkey
   	     AND PICKDETAIL.DropID NOT IN (SELECT LabelNo 
   	                                   FROM #TMP_PACKDETAIL (NOLOCK)
   	                                   WHERE Pickslipno = @c_Pickslipno)  	  
         AND ISNULL(PICKDETAIL.DropID,'') <> ''    	                                   
   	                                   
      OPEN Pick_cur
      
      FETCH NEXT FROM Pick_cur INTO @c_pickdetailkey
      
      WHILE @@FETCH_STATUS = 0 
      BEGIN      
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET PICKDETAIL.DropId = '',
             PICKDETAIL.CaseId = '',
             PICKDETAIL.TrafficCop = NULL
         WHERE PICKDETAIL.Pickdetailkey = @c_pickdetailkey
         
         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63315
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END
      
         FETCH NEXT FROM Pick_cur INTO @c_pickdetailkey
      END
      CLOSE Pick_cur
      DEALLOCATE Pick_cur
      SET @c_pickdetailkey = ''                  
   	  */
   	     	         	  
	    DECLARE CUR_PACKINGDET CURSOR  FAST_FORWARD READ_ONLY FOR
	       SELECT PACKDETAIL.Sku, SUM(PACKDETAIL.Qty) AS Qty, PACKDETAIL.Labelno, PACKDETAIL.RefNo2,
	              PACKHEADER.Orderkey 
	       FROM PACKHEADER (NOLOCK) 
	       JOIN #TMP_PACKDETAIL PACKDETAIL ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
	       WHERE  PACKHEADER.Pickslipno = @c_Pickslipno
	       AND NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)
	                       WHERE PD.Orderkey = PACKHEADER.Orderkey
	                       AND PD.Sku = PACKDETAIL.Sku 
	                       AND PD.DropID = PACKDETAIL.DropId)
	       GROUP BY PACKDETAIL.Sku, PACKDETAIL.Labelno, PACKDETAIL.RefNo2, PACKHEADER.Orderkey 
	       ORDER BY PACKDETAIL.Sku, PACKDETAIL.Labelno, PACKDETAIL.RefNo2
      
	    OPEN CUR_PACKINGDET
      
	    FETCH NEXT FROM CUR_PACKINGDET INTO @c_sku, @n_packqty, @c_labelno, @c_RefNo2, @c_orderkey 
	    WHILE @@FETCH_STATUS <> -1
	    BEGIN
	       SELECT @c_pickdetailkey = ''
		     WHILE @n_packqty > 0
 		     BEGIN                  
           SELECT TOP 1 @c_pickdetailkey = PICKDETAIL.Pickdetailkey, @n_pickqty = Qty
           FROM PICKDETAIL (NOLOCK)
           JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
           WHERE ISNULL(PICKDETAIL.Dropid,'') = ''
           AND PICKDETAIL.Sku = @c_sku
           AND PICKDETAIL.Orderkey = @c_orderkey
           AND LOTATTRIBUTE.Lottable08 = @c_RefNo2
           AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey
           ORDER BY PICKDETAIL.Pickdetailkey
         
           SELECT @n_cnt = @@ROWCOUNT
         
           IF @n_cnt = 0
          	   BREAK
         
           IF @n_pickqty <= @n_packqty
           BEGIN
           	 UPDATE PICKDETAIL WITH (ROWLOCK)
           	 SET DropId = @c_labelno,
           	     CaseID = @c_labelno,
           	     TrafficCop = NULL
           	 WHERE Pickdetailkey = @c_pickdetailkey
           	 
           	 SELECT @n_err = @@ERROR
           	 
           	 IF @n_err <> 0
           	 BEGIN
           		 SELECT @n_continue = 3
           		 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63320
           		 SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
           		 BREAK
		     		 END
		     		 SELECT @n_packqty = @n_packqty - @n_pickqty
         	 END --@n_pickqty <= @n_packqty
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
                 BREAK
              END
         
           	  INSERT PICKDETAIL
                     (PickDetailKey, CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                      Storerkey, Sku, AltSku, UOM, UOMQty, Qty, QtyMoved, Status,
                      DropID, Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                      WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo )
              SELECT @c_newpickdetailkey, '', PickHeaderKey, OrderKey, OrderLineNumber, Lot,
                     Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,
                     '', Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,
                     ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,
                     WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo
              FROM PICKDETAIL (NOLOCK)
              WHERE PickdetailKey = @c_pickdetailkey
         
           	  SELECT @n_err = @@ERROR
              IF @n_err <> 0
              BEGIN
                 SELECT @n_continue = 3
             	   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63330
          		   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                 BREAK
              END
         
              UPDATE PICKDETAIL WITH (ROWLOCK)
           	  SET DropId = @c_labelno,
           	      CaseId = @c_Labelno,
           	      Qty = @n_packqty,
		     		      UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END,
           	      TrafficCop = NULL
           	  WHERE Pickdetailkey = @c_pickdetailkey
           	  
           	  SELECT @n_err = @@ERROR
           	  IF @n_err <> 0
           	  BEGIN
           		  SELECT @n_continue = 3
           		  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63340
           		  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd01)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
           		  BREAK
		     		  END
         
              SELECT @n_packqty = 0
           END -- pickqty > packqty
         END -- @n_packqty > 0 
   	     FETCH NEXT FROM CUR_PACKINGDET INTO @c_sku, @n_packqty, @c_labelno, @c_RefNo2, @c_orderkey 
	    END --CUR_PACKINGDET
	    CLOSE CUR_PACKINGDET
    	DEALLOCATE CUR_PACKINGDET
   END --update pack to pick

QUIT_SP:  --WL01
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
      execute nsp_logerror @n_err, @c_errmsg, "ispPKLBLToOrd01"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR   
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --end sp

GO