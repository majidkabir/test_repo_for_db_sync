SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_RPT_LP_SORTLIST_004                             */  
/* Creation Date: 01-Jun-2023                                            */  
/* Copyright: LFL                                                        */  
/* Written by: CSCHONG                                                   */  
/*                                                                       */  
/* Purpose: WMS-22696-[PH] - Moet Hennessy - Loading Guide Modification  */  
/*                                                                       */  
/* Called By: RPT_LP_SORTLIST_004                                        */  
/*                                                                       */  
/* GitLab Version: 1.0                                                   */  
/*                                                                       */  
/* Version: 7.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author  Ver   Purposes                                    */  
/* 01-Jun-2023 CSCHONG 1.0   DevOps Combine Script                       */  
/*************************************************************************/  
CREATE    PROC [dbo].[isp_RPT_LP_SORTLIST_004]  
                    (@c_Loadkey NVARCHAR(10))  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
 DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         
         , @c_SQL             NVARCHAR(4000)
         , @c_SQLArgument     NVARCHAR(4000)

         , @c_Storerkey       NVARCHAR(15)

         , @n_SortBySKU       INT

         , @c_lottable02label NVARCHAR(60)
         , @c_lottable04label NVARCHAR(60)

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_Storerkey = ''
   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM ORDERS WITH (NOLOCK)
   WHERE Loadkey = @c_Loadkey

   SET @n_SortBySKU = 0

   SELECT @n_SortBySKU      = ISNULL(MAX(CASE WHEN CL.Code = 'SortBySKU' THEN 1 ELSE 0 END),0)
   FROM CODELKUP CL  WITH (NOLOCK) 
   WHERE CL.ListName = 'REPORTCFG' 
   AND   CL.STORERkey  = @c_Storerkey
   AND   CL.Long = 'RPT_LP_SORTLIST_004'
   AND   ISNULL(CL.Short, '') <> 'N'

   SET @c_lottable02label = ''
   SET @c_lottable04label = ''
   SELECT @c_lottable02label = ISNULL(MAX(CASE WHEN CL.Code = 'Lottable02' AND ISNULL(RTRIM(CL.description),'') <> ''  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
         ,@c_lottable04label = ISNULL(MAX(CASE WHEN CL.Code = 'Lottable04' AND ISNULL(RTRIM(CL.description),'') <> ''  THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),'')
   FROM CODELKUP CL  WITH (NOLOCK) 
   WHERE CL.ListName = 'RPTCOLHDR' 
   AND   CL.Storerkey  = @c_Storerkey

   SELECT @c_lottable02label = ISNULL(MAX(CASE WHEN @c_lottable02label <> '' THEN @c_lottable02label
                                               WHEN CL.Code = 'Lottable02' AND ISNULL(RTRIM(CL.description),'') <> ''  
                                               THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),@c_lottable02label)
         ,@c_lottable04label = ISNULL(MAX(CASE WHEN @c_lottable04label <> '' THEN @c_lottable04label
                                               WHEN CL.Code = 'Lottable04' AND ISNULL(RTRIM(CL.description),'') <> ''  
                                               THEN ISNULL(RTRIM(CL.description),'') ELSE '' END),@c_lottable04label)
   FROM CODELKUP CL  WITH (NOLOCK) 
   WHERE CL.ListName = 'RPTCOLHDR' 
   AND   CL.Storerkey= ''

   SET @c_lottable02label = CASE WHEN @c_lottable02label = '' THEN 'Batch No' ELSE @c_lottable02label END
   SET @c_lottable04label = CASE WHEN @c_lottable04label = '' THEN 'Expiry Date' ELSE @c_lottable04label END

QUIT_SP:
     SELECT LOADPLAN.loadkey
        ,  FACILITY = LOADPLAN.FACILITY + ' - ' + ISNULL(RTRIM(FACILITY.Descr),'')
        ,  LOADPLANDETAIL.customername
        ,  STORER.company
        ,  c_address1 = ISNULL(RTRIM(ORDERS.c_address1),'')
        ,  c_address2 = ISNULL(RTRIM(ORDERS.c_address2),'') + ' ' + ISNULL(RTRIM(ORDERS.c_City),'')
        ,  lottable02 = ISNULL(RTRIM(LOTATTRIBUTE.lottable02),'')
        ,  LOTATTRIBUTE.lottable04
        ,  PICKDETAIL.SKU
        ,  SKU.descr
        ,  totalcases = Sum(Pickdetail.Qty/NULLIF(Pack.Casecnt,0))    
        ,  LOADPLANDETAIL.consigneekey
        ,  UserName = SUSER_SNAME() 
        ,  lottable02label = @c_lottable02label 
        ,  lottable04label = @c_lottable04label
        ,  copyname = pg.Description 
        ,  copycode = pg.code 
        ,  copyshowcolumn = pg.short 
        ,  userdefine12 = ISNULL(RTRIM(FACILITY.userdefine12),'')
        ,  route = ISNULL(RTRIM(LOADPLAN.route),'')
        ,  Externorderkey = ISNULL(RTRIM(ORDERS.Externorderkey),'')
        ,  BuyerPO        = ISNULL(RTRIM(ORDERS.BuyerPO),'')
        ,  LEXTLoadKey    = ISNULL(RTRIM(LOADPLAN.Externloadkey),'')                                    
        ,  LPriority      = LOADPLAN.Priority                                       
        ,  LPuserdefDate01  = LOADPLAN.LPuserdefDate01 
        ,  BookingNo = ISNULL(LOADPLAN.BookingNo,0)
        ,  OrderGroup= ISNULL(RTRIM(ORDERS.OrderGroup),'')
        ,  RowRef = ROW_NUMBER() OVER ( ORDER BY  pg.Description,PICKDETAIL.Dropid                                              
                                               ,  PICKDETAIL.SKU
                                               ,  ISNULL(RTRIM(LOTATTRIBUTE.lottable02),'') 
                                      )                                   
       ,  DropID  = PICKDETAIL.Dropid
       ,  WGT     = SUM(SKU.STDGROSSWGT * PICKDETAIL.qty)
       ,  totalPCS = SUM(PICKDETAIL.qty) 
       ,  LFcopy = CASE WHEN pg.Description LIKE '%LF%' THEN 'Y' ELSE 'N' END 
   FROM LOADPLAN WITH (NOLOCK) 
   JOIN FACILITY WITH (NOLOCK) ON (LOADPLAN.FACILITY = FACILITY.FACILITY)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.loadkey = LOADPLANDETAIL.loadkey)
   JOIN ORDERS   WITH (NOLOCK) ON (LOADPLANDETAIL.orderkey = ORDERS.orderkey)
   JOIN dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = ORDERS.Orderkey 
   JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.orderkey = OD.orderkey AND OD.OrderLineNumber = PICKDETAIL.Orderlinenumber AND OD.SKU = Pickdetail.sku)
   JOIN STORER   WITH (NOLOCK) ON (ORDERS.STORERkey = STORER.STORERkey)
   JOIN PACK     WITH (NOLOCK) ON (PICKDETAIL.PACKkey = PACK.PACKkey)
   JOIN SKU      WITH (NOLOCK) ON (PICKDETAIL.SKU = SKU.SKU and PICKDETAIL.STORERkey = SKU.STORERkey)  
   JOIN LOTATTRIBUTE  WITH (NOLOCK) ON (PICKDETAIL.lot = LOTATTRIBUTE.lot)
   LEFT JOIN CODELKUP pg WITH (NOLOCK) ON (pg.listname = 'REPORTCOPY')
                                      --AND (pg.long = 'r_dw_sortlist14')  
                                      AND (pg.long = 'RPT_LP_SORTLIST_004')      
                                      AND (pg.STORERkey = ORDERS.STORERkey)
   WHERE LOADPLAN.loadkey = @c_Loadkey
   GROUP BY  LOADPLAN.loadkey
          ,  LOADPLAN.FACILITY
          ,  LOADPLANDETAIL.customername
          ,  STORER.company
          ,  ISNULL(RTRIM(ORDERS.c_address1),'')
          ,  ISNULL(RTRIM(ORDERS.c_address2),'') 
          ,  ISNULL(RTRIM(ORDERS.c_City),'')
          ,  ISNULL(RTRIM(LOTATTRIBUTE.lottable02),'')
          ,  LOTATTRIBUTE.lottable04
          ,  PICKDETAIL.SKU
          ,  SKU.descr
          ,  LOADPLANDETAIL.consigneekey
          ,  PACK.casecnt
          ,  PACK.Qty
          ,  pg.description 
          ,  pg.code
          ,  pg.short
          ,  ORDERS.STORERkey
          ,  ISNULL(RTRIM(FACILITY.Descr),'')
          ,  ISNULL(RTRIM(FACILITY.userdefine12),'')
          ,  ISNULL(RTRIM(LOADPLAN.route),'') 
          ,  ISNULL(RTRIM(ORDERS.Externorderkey),'')
          ,  ISNULL(RTRIM(ORDERS.BuyerPO),'')
          ,  ISNULL(RTRIM(LOADPLAN.Externloadkey),'')                                    
          ,  LOADPLAN.Priority                                          
          ,  LOADPLAN.LPuserdefDate01  
          ,  ISNULL(LOADPLAN.BookingNo,0)
          ,  ISNULL(RTRIM(ORDERS.OrderGroup),'')
          ,  PICKDETAIL.Dropid ,OD.UOM
     ORDER BY RowRef


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 
END  
SET QUOTED_IDENTIFIER OFF 

GO