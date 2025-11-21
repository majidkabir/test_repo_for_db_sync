SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Stored Proc : ispPKLBLToOrd03                                        */  
/* Creation Date: 21-Dec-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-15715 - Extract lottable value from packdetail upc and  */
/*          match with pickdetail lottable12                            */  
/*                                                                      */  
/* Called By: isp_AssignPackLabelToOrderByLoad - Confirm pick           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[ispPKLBLToOrd03]  
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
     
   DECLARE @n_continue        INT,  
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
           @c_loadkey                  NVARCHAR(10),
           @c_UPC                      NVARCHAR(30)   

   SELECT TOP 1 @c_Orderkey  = PACKHEADER.Orderkey  
              , @c_loadkey   = PACKHEADER.Loadkey
              , @c_Storerkey = PACKHEADER.StorerKey
   FROM PACKHEADER (NOLOCK)  
   JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
   WHERE PACKHEADER.Pickslipno = @c_Pickslipno  
   ORDER BY PACKDETAIL.LabelNo DESC  
      
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_Option4,'') <> 'SKIPSTAMPED'
   BEGIN  
      -- Clear all the dropid(labelno) for re-assign in case of pack status reversal by manual and confirm pack again in future  
      IF ISNULL(@c_orderkey,'')=''  
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
                SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63330  
                SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
           END  
     
         FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
      END  
      CLOSE PickDet_cur  
      DEALLOCATE PickDet_cur  
      SET @c_pickdetailkey = ''  
   END  
     
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
     IF ISNULL(@c_Option4,'') = 'SKIPSTAMPED' 
     BEGIN  
         DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,
                   PACKHEADER.Orderkey, SUBSTRING(LTRIM(RTRIM(ISNULL(PACKDETAIL.UPC,''))),22,6)
            FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
            WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
            AND NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)  
                            WHERE PD.Orderkey = PACKHEADER.Orderkey  
                            AND PD.Sku = PACKDETAIL.Sku   
                            AND PD.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PACKDETAIL.LabelNo ELSE PD.CaseID END  
                            AND PD.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PD.DropID ELSE PACKDETAIL.LabelNo END  
                            )  
            AND PACKHEADER.Orderkey <> ''  
            AND PACKHEADER.Orderkey IS NOT NULL  
            UNION ALL
            SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,
                   PACKHEADER.Orderkey, SUBSTRING(LTRIM(RTRIM(ISNULL(PACKDETAIL.UPC,''))),22,6)
            FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
            WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
            AND NOT EXISTS (SELECT 1 FROM PICKDETAIL PD (NOLOCK)  
                            JOIN LOADPLANDETAIL LPD (NOLOCK) ON PD.Orderkey = LPD.Orderkey  
                            WHERE LPD.Loadkey = PACKHEADER.Loadkey  
                            AND PD.Sku = PACKDETAIL.Sku   
                            AND PD.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PACKDETAIL.LabelNo ELSE PD.CaseID END  
                            AND PD.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PD.DropID ELSE PACKDETAIL.LabelNo END  
                            )  
            AND (PACKHEADER.Orderkey = '' OR PACKHEADER.Orderkey IS NULL)  
            ORDER BY 1, 3  
     END  
     ELSE  
     BEGIN      
         DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,
                PACKHEADER.Orderkey, SUBSTRING(LTRIM(RTRIM(ISNULL(PACKDETAIL.UPC,''))),22,6)  
         FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
         WHERE  PACKHEADER.Pickslipno = @c_Pickslipno --NJOW03  
         ORDER BY PACKDETAIL.Sku, PACKDETAIL.Labelno  
      END  
     
      OPEN CUR_PACKDET  
     
      FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey, @c_UPC
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
        SELECT @c_pickdetailkey = ''  
         WHILE @n_packqty > 0  
         BEGIN  
            IF @c_OPtion3 <> 'FullLabelNo'  
            BEGIN  
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
                       + ' JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON LA.LOT = PICKDETAIL.LOT'
                       + CASE WHEN ISNULL(@c_orderkey,'')=''   
                              THEN ' WHERE LOADPLANDETAIL.Loadkey = @c_loadkey'   
                              ELSE ' WHERE PICKDETAIL.Orderkey = @c_orderkey'   
                              END  
                       + ' AND PICKDETAIL.Sku = @c_sku'  
                       + ' AND PICKDETAIL.storerkey = @c_storerkey'
                       + CASE WHEN @c_Option2 = 'CaseID'   
                              THEN ' AND (PICKDETAIL.CaseID = '''' OR PICKDETAIL.CaseID IS NULL)'   
                              ELSE ' AND (PICKDETAIL.Dropid = '''' OR PICKDETAIL.Dropid IS NULL)'   
                              END  
                       + ' AND PICKDETAIL.Pickdetailkey > @c_pickdetailkey'  
                       + ' AND LA.Lottable12 = @c_UPC'
                       --+ ' ORDER BY PICKDETAIL.Pickdetailkey'  
                       + ' ORDER BY CASE WHEN PICKDETAIL.Qty = @n_PackQty THEN 1 ELSE PICKDETAIL.Pickdetailkey END  '

            SET @c_SQLArgument = N'@n_cnt             INT            OUTPUT'  
                               + ',@n_pickqty         INT            OUTPUT'  
                               + ',@c_PickDetailKey   NVARCHAR(10)   OUTPUT'  
                               + ',@c_loadkey         NVARCHAR(10)'  
                               + ',@c_orderkey        NVARCHAR(10)'  
                               + ',@c_sku             NVARCHAR(20)'  
                               + ',@c_StorerKey       NVARCHAR(15)' 
                               + ',@c_UPC             NVARCHAR(30)' 
                               + ',@n_packqty         INT' 
       
            EXEC sp_executesql @c_SQL  
                  ,  @c_SQLArgument  
                  ,  @n_Cnt            OUTPUT  
                  ,  @n_pickqty        OUTPUT   
                  ,  @c_PickDetailKey  OUTPUT  
                  ,  @c_loadkey  
                  ,  @c_orderkey         
                  ,  @c_sku  
                  ,  @c_StorerKey  
                  ,  @c_UPC
                  ,  @n_packqty
     
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
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63331  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                       WaveKey, EffectiveDate, OptimizeCop, ShipFlag, PickSlipNo, Channel_ID    -- ZG01  
                     , TaskDetailKey                                                --(Wan02)  
                      )  
               SELECT @c_newpickdetailkey  
                    , CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END                             --(Wan01)  
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                      Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,  
                      CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END                             --(Wan01)                              
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo, Channel_ID             -- ZG01
                    , TaskDetailKey                                                --(Wan02)  
               FROM PICKDETAIL (NOLOCK)  
               WHERE PickdetailKey = @c_pickdetailkey  
     
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                 SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63332  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispPKLBLToOrd03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63333  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd03)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
     
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0  
        FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey, @c_UPC
      END -- Cursor While  
      DEALLOCATE CUR_PACKDET  
   END  
  
QUIT_SP:
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
      execute nsp_logerror @n_err, @c_errmsg, "ispPKLBLToOrd03"  
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