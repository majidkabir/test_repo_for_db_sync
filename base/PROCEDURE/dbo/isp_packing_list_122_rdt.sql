SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* StoredProc: isp_Packing_List_122_rdt                                 */    
/* Creation Date: 10-MAR-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: MINGLE                                                   */    
/*                                                                      */    
/* Purpose:                                                             */    
/*        :                                                             */    
/* Called By: r_dw_packing_list_122_rdt                                 */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 11-MAR-2022 Mingle   1.0   Created(WMS-19075) DevOps Combine Script  */     
/* 18-OCT-2022 Mingle   1.1   Created(WMS-21007) Add new mappings(ML01) */    
/* 14-FEB-2023 Mingle   1.2   WMS-21733 Add new mappings(ML02)          */    
/************************************************************************/    
CREATE    PROC [dbo].[isp_Packing_List_122_rdt] (    
   @c_Pickslipno NVARCHAR(10)    
)    
AS     
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
   DECLARE    
           @n_StartTCnt       INT    
         , @n_Continue        INT    
         , @n_NoOfLine        INT    
         , @c_platfrom        NVARCHAR(20)   
			, @c_clshort			NVARCHAR(20)
         , @c_clnotes         NVARCHAR(100)
         , @c_Text            NVARCHAR(100)
         , @c_Left            NVARCHAR(100)
         , @c_Right           NVARCHAR(100)
      
    
   SET @n_StartTCnt = @@TRANCOUNT    
    
   WHILE @@TRANCOUNT > 0    
   BEGIN    
      COMMIT TRAN    
   END    
    
   IF LEFT(@c_Pickslipno,1) = 'P' -- Print from ECOM Packing    
   BEGIN    
      SELECT @c_Pickslipno = Orderkey    
      FROM PICKHEADER WITH (NOLOCK)    
      WHERE PickHeaderKey = @c_Pickslipno    
   END    
    
   SELECT @c_platfrom = ORDERS.ECOM_PLATFORM,@c_clshort = CL.Short,@c_clnotes = CL.Notes   
   FROM ORDERS(NOLOCK)    
	LEFT JOIN CODELKUP CL(NOLOCK) ON CL.LISTNAME = 'fabdef' AND CL.Storerkey = ORDERS.STORERKEY AND CL.Long = ORDERS.SALESMAN  
   WHERE ORDERS.ORDERKEY = @c_Pickslipno	--ML01    
       
    
   --IF @c_platfrom IN (SELECT short FROM CODELKUP (NOLOCK) WHERE LISTNAME='ECPlatform' AND Storerkey='fabrique' AND code<>'GW')    
   --BEGIN     
   --   SET @n_NoOfLine = '4'    
   --END    
   
	--START ML01
   IF @c_clshort = '0'  
   BEGIN    
      SET @n_NoOfLine = '6'    
   END    
	ELSE IF @c_clshort = '1'  
	BEGIN    
      SET @n_NoOfLine = '4'    
   END    
	ELSE IF @c_clshort = '2'  
	BEGIN    
      SET @n_NoOfLine = '4'    
   END   
	--END ML01

   --START ML02
   SET @c_Text = @c_clnotes

   SELECT @c_Left = ColValue FROM dbo.fnc_DelimSplit('/', @c_Text) FDS WHERE FDS.SeqNo = 1
   SELECT @c_Right = ColValue FROM dbo.fnc_DelimSplit('/', @c_Text) FDS WHERE FDS.SeqNo = 2
   --END ML02
   
   --SELECT @c_Left, @c_Right
       
   SELECT ORDERS.ExternOrderkey,    
          SKU.DESCR,    
          SKU.SIZE,    
          SUM(PICKDETAIL.QTY),   
          ORDERDETAIL.ExtendedPrice,    
          Orders.M_Contact1,    
          --GETDATE(),    
          convert(varchar, getdate(), 3),    
          SUM(ORDERDETAIL.ExtendedPrice/2) AS F8,    
          (SUM(ORDERDETAIL.ExtendedPrice/2)/10) AS F9,    
          (Row_Number() OVER (PARTITION BY orderdetail.OrderKey ORDER BY pickdetail.SKU Asc)-1)/@n_NoOfLine AS RecGrp,    
          @n_NoOfLine AS showmaxline,  
			 CL1.UDF01, --ML01  
			 CL1.UDF02, --ML01  
			 CL1.UDF03, --ML01    
			 ISNULL(cl1.short,'') AS clshort,	--ML01
          @c_Left,   --ML02
          @c_Right   --ML02
   FROM ORDERS (NOLOCK)    
   JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.OrderKey = ORDERS.OrderKey     
   JOIN PICKDETAIL (NOLOCK) ON ORDERS.OrderKey = PICKDETAIL.OrderKey AND ORDERDETAIL.OrderLineNumber=PICKDETAIL.OrderLineNumber    
   JOIN SKU  (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)      
	LEFT JOIN CODELKUP CL1(NOLOCK) ON CL1.LISTNAME = 'fabdef' AND CL1.Storerkey = ORDERS.STORERKEY AND CL1.Long = ORDERS.SALESMAN  
   WHERE ORDERS.Orderkey = @c_Pickslipno    
   GROUP BY ORDERS.ExternOrderkey,    
          SKU.DESCR,    
          SKU.SIZE,      
          ORDERDETAIL.ExtendedPrice,    
          Orders.M_Contact1,    
          orderdetail.OrderKey,    
          pickdetail.SKU,  
			 CL1.UDF01, --ML01  
			 CL1.UDF02, --ML01  
			 CL1.UDF03, --ML01    
			 ISNULL(cl1.short,''),	--ML01  
          cl1.notes	--ML02
QUIT_SP:    
      WHILE @@TRANCOUNT < @n_StartTCnt    
      BEGIN    
         BEGIN TRAN    
      END    
END -- procedure

GO