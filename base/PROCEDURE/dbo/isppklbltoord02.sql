SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


  
/************************************************************************/  
/* Stored Proc : ispPKLBLToOrd02                                        */  
/* Creation Date: 02/10/2020                                            */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-15190 - SG Prestige Assign pack label# to picketail     */  
/*                                                                      */  
/* Called By: Confirm pick                                              */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */  
/* 29-Mar-2022 WLChooi  1.1   DevOps Combine Script                     */ 
/* 29-Mar-2022 WLChooi  1.1   WMS-19346 - Enhance logic (WL01)          */
/* 14-Jun-2022 WLChooi  1.2   WMS-19948 - Enhance logic (WL02)          */
/* 07-Jul-2022 Calvin	1.3   JSM-79951 - Include Channel_ID  (CLVN01)  */
/*                                        and TaskManagerReasonKey      */
/************************************************************************/  
  
CREATE   PROC [dbo].[ispPKLBLToOrd02]  
(@c_Pickslipno NVARCHAR(10),  
 @b_Success      INT       OUTPUT,  
 @n_err          INT       OUTPUT,  
 @c_errmsg       NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
  
   SET NOCOUNT ON       -- SQL 2005 Standard  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_continue            INT,  
           @c_debug               NVARCHAR(1),  
           @n_starttcnt           INT,  
           @n_cnt                 INT  
     
   SELECT @c_debug = '0'  
     
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT, @b_success=0, @n_err=0  
     
   DECLARE @c_sku                 NVARCHAR(20),  
           @n_packqty             INT,  
           @n_pickqty             INT,  
           @n_splitqty            INT,  
           @c_labelno             NVARCHAR(20),  
           @c_pickdetailkey       NVARCHAR(10),  
           @c_newpickdetailkey    NVARCHAR(10),  
           @c_orderkey            NVARCHAR(10),  
           @c_loadkey             NVARCHAR(10),    
           @n_TotPickQty          INT,  
           @n_TotPackQty          INT,
           @c_LottableValue       NVARCHAR(60),
           @c_PackByLottable      NVARCHAR(30),
           @c_PackByLottable_Opt1 NVARCHAR(50)
     
   DECLARE @c_AssignPackLabelToOrdCfg NVARCHAR(30),  
           @c_storerkey               NVARCHAR(15),  
           @c_facility                NVARCHAR(5),  
           @c_option1                 NVARCHAR(50),  
           @c_option2                 NVARCHAR(50),  
           @c_option3                 NVARCHAR(50),  
           @c_option4                 NVARCHAR(50),  
           @c_option5                 NVARCHAR(4000),  
           @c_SQL                     NVARCHAR(2000),  
           @c_SQLArgument             NVARCHAR(4000)         
     
   SET @c_pickdetailkey = ''  
  
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      SELECT @c_loadkey = Loadkey,  
             @c_orderkey = Orderkey  
      FROM PACKHEADER WITH (NOLOCK)  
      WHERE Pickslipno = @c_Pickslipno  
     
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
         SELECT @n_err = 63334  
         SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Total PackQty ('+ CAST(@n_TotPackQty AS VARCHAR) +  
                            ') vs PickQty ('+ CAST(@n_TotPickQty AS VARCHAR) +') Not Tally. (ispPKLBLToOrd02)'  
      END  
   END  
    
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
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
         @c_Facility = @c_facility,    
         @c_StorerKey = @c_StorerKey,                
         @c_sku  = '',                      
         @c_ConfigKey = 'AssignPackLabelToOrdCfg', -- Configkey  
         @b_Success = @b_success    OUTPUT,  
         @c_authority = @c_AssignPackLabelToOrdCfg OUTPUT,  
         @n_err = @n_err                           OUTPUT,  
         @c_errmsg = @c_errmsg                     OUTPUT,  
         @c_Option1 = @c_option1                   OUTPUT, --ispPKLBLToOrd??  
         @c_Option2 = @c_option2                   OUTPUT, --CaseID => Update Pickdetail.CaseID  
         @c_Option3 = @c_option3                   OUTPUT, --FullLabelNo  
         @c_Option4 = @c_option4                   OUTPUT, --skipstamped  
         @c_Option5 = @c_option5                   OUTPUT        
   
      EXECUTE nspGetRight   
         @c_Facility = @c_facility,    
         @c_StorerKey = @c_StorerKey,                
         @c_sku  = '',                      
         @c_ConfigKey = 'PackByLottable', -- Configkey  
         @b_Success = @b_success             OUTPUT,  
         @c_authority = @c_PackByLottable    OUTPUT,  
         @n_err = @n_err                     OUTPUT,  
         @c_errmsg = @c_errmsg               OUTPUT,  
         @c_Option1 = @c_PackByLottable_Opt1 OUTPUT  
   END  

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
         SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END    
            ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END   
            ,TrafficCop = NULL  
         WHERE PICKDETAIL.Pickdetailkey = @c_pickdetailkey  
         
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
              SELECT @n_continue = 3  
              SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63330  
              SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
     
         FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
      END  
      CLOSE PickDet_cur  
      DEALLOCATE PickDet_cur  
      SET @c_pickdetailkey = ''  
   END  

   --WL01 S
   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_Option4,'') = 'SKIPSTAMPED'   
   BEGIN  
      -- Clear all the dropid(labelno) for those that are not already stamped for re-assign 
      -- in case of pack status reversal by manual and confirm pack again in future  
      IF ISNULL(@c_orderkey,'') = '' 
      BEGIN  
         DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PICKDETAIL.Pickdetailkey  
            FROM LOADPLANDETAIL WITH (NOLOCK) INNER JOIN PICKDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey  
            WHERE LOADPLANDETAIL.Loadkey = @c_loadkey  
            AND NOT EXISTS (SELECT 1 FROM PACKHEADER PAH (NOLOCK)
                            JOIN PACKDETAIL PAD (NOLOCK) ON PAH.PickSlipNo = PAD.PickSlipNo
                            WHERE PAH.Orderkey = PICKDETAIL.Orderkey  
                            AND PAD.Sku = PICKDETAIL.Sku   
                            AND PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PAD.LabelNo ELSE PICKDETAIL.CaseID END  
                            AND PICKDETAIL.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropID ELSE PAD.LabelNo END  
                            AND ((SELECT SUM(QTY)  --WL02 S
                                  FROM PICKDETAIL PD1 (NOLOCK) 
                                  JOIN LOADPLANDETAIL LPD1 (NOLOCK) ON LPD1.OrderKey = PD1.OrderKey
                                  WHERE LPD1.LoadKey = @c_loadkey
                                  AND PD1.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PAD.LabelNo ELSE PD1.CaseID END 
                                  AND PD1.DROPID = CASE WHEN @c_Option2 = 'CaseID' THEN PD1.DropID ELSE PAD.LabelNo END) = 
                                  (SELECT SUM(QTY) 
                                   FROM PACKDETAIL PAD1 (NOLOCK) 
                                   WHERE PAD1.PickSlipNo = PAH.PickSlipNo 
                                   AND PAD1.LabelNo = PAD.LabelNo))   --WL02 E
                            )  
      END  
      ELSE  
      BEGIN  
         DECLARE PickDet_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PICKDETAIL.Pickdetailkey  
            FROM  PICKDETAIL WITH (NOLOCK)  
            WHERE PICKDETAIL.Orderkey = @c_orderkey  
            AND NOT EXISTS (SELECT 1 FROM PACKHEADER PAH (NOLOCK)
                            JOIN PACKDETAIL PAD (NOLOCK) ON PAH.PickSlipNo = PAD.PickSlipNo
                            WHERE PAH.Orderkey = PICKDETAIL.Orderkey  
                            AND PAD.Sku = PICKDETAIL.Sku   
                            AND PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PAD.LabelNo ELSE PICKDETAIL.CaseID END  
                            AND PICKDETAIL.DropID = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropID ELSE PAD.LabelNo END
                            AND ((SELECT SUM(QTY)  --WL02 S
                                  FROM PICKDETAIL PD1 (NOLOCK) 
                                  WHERE PD1.ORDERKEY = @c_orderkey
                                  AND PD1.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN PAD.LabelNo ELSE PD1.CaseID END 
                                  AND PD1.DROPID = CASE WHEN @c_Option2 = 'CaseID' THEN PD1.DropID ELSE PAD.LabelNo END) = 
                                  (SELECT SUM(QTY) 
                                   FROM PACKDETAIL PAD1 (NOLOCK) 
                                   WHERE PAD1.PickSlipNo = PAH.PickSlipNo 
                                   AND PAD1.LabelNo = PAD.LabelNo))   --WL02 E
                            )  
      END  
     
      OPEN PickDet_cur  
      FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
      WHILE @@FETCH_STATUS = 0 AND ( @n_continue = 1 OR @n_continue = 2 )  
      BEGIN  
         UPDATE PICKDETAIL WITH (ROWLOCK)  
         SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END    
            ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END   
            ,TrafficCop = NULL  
         WHERE PICKDETAIL.Pickdetailkey = @c_pickdetailkey  
         
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63334 
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         END  
     
         FETCH NEXT FROM PickDet_cur INTO @c_pickdetailkey  
      END  
      CLOSE PickDet_cur  
      DEALLOCATE PickDet_cur  
      SET @c_pickdetailkey = ''  
   END
   --WL01 E
    
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  
      IF ISNULL(@c_Option4,'') = 'SKIPSTAMPED' 
      BEGIN  
         DECLARE CUR_PACKDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT PACKDETAIL.Sku, PACKDETAIL.Qty, PACKDETAIL.Labelno,  
                   PACKHEADER.Orderkey, PACKDETAIL.LottableValue 
            FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
            WHERE  PACKHEADER.Pickslipno = @c_Pickslipno 
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
                   PACKHEADER.Orderkey, PACKDETAIL.LottableValue
            FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
            WHERE  PACKHEADER.Pickslipno = @c_Pickslipno 
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
                   PACKHEADER.Orderkey, PACKDETAIL.LottableValue 
            FROM   PACKHEADER (NOLOCK) INNER JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno  
            WHERE  PACKHEADER.Pickslipno = @c_Pickslipno   
            ORDER BY CASE WHEN PACKDETAIL.LottableValue <> '' AND PACKDETAIL.LottableValue IS NOT NULL THEN 1 ELSE 2 END, PACKDETAIL.Sku, PACKDETAIL.Labelno  
      END  
  
      OPEN CUR_PACKDET  
  
      FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey, @c_LottableValue 
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @c_pickdetailkey = ''  
         WHILE @n_packqty > 0  
         BEGIN  
            /*IF @c_OPtion3 <> 'FullLabelNo'  
            BEGIN  
               IF LEN(LTRIM(RTRIM(@c_labelno))) > 18  
               BEGIN  
                  IF LEFT(LTRIM(@c_labelno),2) = '00'  
                  BEGIN  
                     SET @c_labelno = RIGHT(LTRIM(RTRIM(@c_labelno)),18)  
                  END  
               END  
            END*/  
         
            SET @n_cnt = 0                    
            SET @c_SQL = N'SELECT TOP 1 @n_cnt = 1'  
                       + ',@n_pickqty = PICKDETAIL.Qty'  
                       + ',@c_pickdetailkey = PICKDETAIL.Pickdetailkey'  
                       + ' FROM PICKDETAIL WITH (NOLOCK)'  
                       + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot'
                       + CASE WHEN ISNULL(@c_orderkey,'')=''   
                              THEN ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey'   
                              ELSE ''   
                              END  
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
                       + CASE WHEN @c_PackByLottable = '1' AND ISNULL(@c_PackByLottable_Opt1,'') <> '' AND ISNULL(@c_LottableValue,'') <> ''
                              THEN ' AND LOTATTRIBUTE.Lottable'  + LTRIM(RTRIM(@c_PackByLottable_Opt1)) + ' = @c_LottableValue'
                              ELSE '' 
                              END
                       --+ ' AND PICKDETAIL.Pickdetailkey > @c_Pickdetailkey'  
                       + CASE WHEN @c_PackByLottable = '1' AND ISNULL(@c_PackByLottable_Opt1,'') <> '' 
                              THEN ' ORDER BY LOTATTRIBUTE.Lottable'  + LTRIM(RTRIM(@c_PackByLottable_Opt1)) + ', PICKDETAIL.Pickdetailkey'
                              ELSE ' ORDER BY PICKDETAIL.Pickdetailkey' 
                              END
         
            SET @c_SQLArgument = N'@n_cnt             INT            OUTPUT'  
                               + ',@n_pickqty         INT            OUTPUT'  
                               + ',@c_PickDetailKey   NVARCHAR(10)   OUTPUT'  
                               + ',@c_loadkey         NVARCHAR(10)'  
                               + ',@c_orderkey        NVARCHAR(10)'  
                               + ',@c_sku             NVARCHAR(20)'  
                               + ',@c_StorerKey       NVARCHAR(15)'  
                               + ',@c_LottableValue   NVARCHAR(60)'  
         
            EXEC sp_executesql @c_SQL  
                  ,  @c_SQLArgument  
                  ,  @n_Cnt            OUTPUT  
                  ,  @n_pickqty        OUTPUT   
                  ,  @c_PickDetailKey  OUTPUT  
                  ,  @c_loadkey  
                  ,  @c_orderkey         
                  ,  @c_sku  
                  ,  @c_StorerKey 
                  ,  @c_LottableValue 
            
            --not filter lottable value                       
            IF @n_cnt = 0 AND @c_PackByLottable = '1' AND ISNULL(@c_PackByLottable_Opt1,'') <> '' AND ISNULL(@c_LottableValue,'') <> ''
            BEGIN 
               SET @c_SQL = N'SELECT TOP 1 @n_cnt = 1'  
                          + ',@n_pickqty = PICKDETAIL.Qty'  
                          + ',@c_pickdetailkey = PICKDETAIL.Pickdetailkey'  
                          + ' FROM PICKDETAIL WITH (NOLOCK)'  
                          + ' JOIN LOTATTRIBUTE WITH (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot'
                          + CASE WHEN ISNULL(@c_orderkey,'')=''   
                                 THEN ' JOIN LOADPLANDETAIL WITH (NOLOCK) ON LOADPLANDETAIL.Orderkey = PICKDETAIL.Orderkey'   
                                 ELSE ''   
                                 END  
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
                          --+ ' AND PICKDETAIL.Pickdetailkey > @c_Pickdetailkey'  
                          + CASE WHEN @c_PackByLottable = '1' AND ISNULL(@c_PackByLottable_Opt1,'') <> '' 
                                 THEN ' ORDER BY LOTATTRIBUTE.Lottable'  + LTRIM(RTRIM(@c_PackByLottable_Opt1)) + ', PICKDETAIL.Pickdetailkey'
                                 ELSE ' ORDER BY PICKDETAIL.Pickdetailkey' 
                                 END
               
               SET @c_SQLArgument = N'@n_cnt             INT            OUTPUT'  
                                  + ',@n_pickqty         INT            OUTPUT'  
                                  + ',@c_PickDetailKey   NVARCHAR(10)   OUTPUT'  
                                  + ',@c_loadkey         NVARCHAR(10)'  
                                  + ',@c_orderkey        NVARCHAR(10)'  
                                  + ',@c_sku             NVARCHAR(20)'  
                                  + ',@c_StorerKey       NVARCHAR(15)'  
                                  + ',@c_LottableValue   NVARCHAR(60)'  
               
               EXEC sp_executesql @c_SQL  
                     ,  @c_SQLArgument  
                     ,  @n_Cnt            OUTPUT  
                     ,  @n_pickqty        OUTPUT   
                     ,  @c_PickDetailKey  OUTPUT  
                     ,  @c_loadkey  
                     ,  @c_orderkey         
                     ,  @c_sku  
                     ,  @c_StorerKey 
                     ,  @c_LottableValue          	
            END       
            
            IF @n_cnt = 0  
               BREAK  
         
            IF @n_pickqty <= @n_packqty  
            BEGIN  
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE @c_labelno END    
                  ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN @c_labelno ELSE PICKDETAIL.CaseID END   
                  ,TrafficCop = NULL  
               WHERE Pickdetailkey = @c_pickdetailkey
                 
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63331  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
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
                     , TaskDetailKey, Channel_ID, TaskManagerReasonKey	--(CLVN01)                                                
                      )  
               SELECT @c_newpickdetailkey  
                    , CASE WHEN @c_Option2 = 'CaseID' THEN '' ELSE PICKDETAIL.CaseID END                              
                    , PickHeaderKey, OrderKey, OrderLineNumber, Lot,  
                      Storerkey, Sku, AltSku, UOM, CASE UOM WHEN '6' THEN @n_splitqty ELSE UOMQty END , @n_splitqty, QtyMoved, Status,  
                      CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE '' END                                                          
                    , Loc, ID, PackKey, UpdateSource, CartonGroup, CartonType,  
                      ToLoc, DoReplenish, ReplenishZone, DoCartonize, PickMethod,  
                      WaveKey, EffectiveDate, '9', ShipFlag, PickSlipNo  
                    , TaskDetailKey, Channel_ID, TaskManagerReasonKey	--(CLVN01)                                               
               FROM PICKDETAIL (NOLOCK)  
               WHERE PickdetailKey = @c_pickdetailkey  
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0  
               BEGIN  
                  SELECT @n_continue = 3  
                  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63332  
                  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Pickdetail Table Failed. (ispPKLBLToOrd02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                  BREAK  
               END  
         
               UPDATE PICKDETAIL WITH (ROWLOCK)  
               SET PICKDETAIL.DropId = CASE WHEN @c_Option2 = 'CaseID' THEN PICKDETAIL.DropId ELSE @c_labelno END   
                  ,PICKDETAIL.CaseID = CASE WHEN @c_Option2 = 'CaseID' THEN @c_labelno ELSE PICKDETAIL.CaseID END   
                  ,Qty = @n_packqty  
                  ,UOMQTY = CASE UOM WHEN '6' THEN @n_packqty ELSE UOMQty END   
                  ,TrafficCop = NULL  
                WHERE Pickdetailkey = @c_pickdetailkey  
                SELECT @n_err = @@ERROR  
                IF @n_err <> 0  
                BEGIN  
                   SELECT @n_continue = 3  
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 63333  
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Pickdetail Table Failed. (ispPKLBLToOrd02)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
                   BREAK  
                END  
         
               SELECT @n_packqty = 0  
            END  
         END -- While packqty > 0  
         FETCH NEXT FROM CUR_PACKDET INTO @c_sku, @n_packqty, @c_labelno, @c_orderkey, @c_LottableValue  
      END -- Cursor While  
      DEALLOCATE CUR_PACKDET  
   END  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ispPKLBLToOrd02"  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
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
END  

GO