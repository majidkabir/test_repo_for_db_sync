SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/        
/* Stored Procedure: isp_packing_list_129_rdt	                        */        
/* CreatiON Date: 11-JAN-2023                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-21252 (TW)                                              */      
/*                                                                      */        
/* Called By: r_dw_Packing_List_129_rdt	            						*/        
/*                                                                      */        
/* PVCS VersiON: 1.0                                                    */        
/*                                                                      */        
/* VersiON: 7.0                                                         */        
/*                                                                      */        
/* Data ModificatiONs:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 09-Feb-2023  WZPang    1.0   Devops Scripts Combine                  */
/************************************************************************/        
CREATE   PROC [dbo].[isp_Packing_List_129_rdt] (
      @c_PickSlipNo	NVARCHAR(10),
	   @c_FromCarton  INT,
	   @c_ToCarton	   INT
	  
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON 
   
   --DECLARE @c_pickslipno NVARCHAR(20)

   --SELECT @c_pickslipno = ISNULL(RTRIM(PickSlipNo),'')
   --FROM PackHeader(NOLOCK)
   --WHERE OrderKey = @c_Orderkey

   DECLARE @c_Storerkey NVARCHAR(15)
         ,@c_c1         NVARCHAR(30)
         ,@c_c2         NVARCHAR(30)
         ,@c_c3         NVARCHAR(30)
         ,@c_c4         NVARCHAR(30)
         ,@c_c5         NVARCHAR(30)
         ,@c_c6         NVARCHAR(30)
         ,@c_c7         NVARCHAR(30)
         ,@c_c8         NVARCHAR(30)
         ,@c_c9         NVARCHAR(30)
         ,@c_c10         NVARCHAR(30)
         ,@c_c11         NVARCHAR(30)
         ,@c_c12         NVARCHAR(30)
         ,@c_c13         NVARCHAR(30)
         ,@c_c14         NVARCHAR(30)
         ,@c_c15         NVARCHAR(30)
         ,@c_c16         NVARCHAR(30)
         ,@c_c17         NVARCHAR(30)
         ,@c_c18         NVARCHAR(30)
         ,@c_c19         NVARCHAR(30)
         ,@c_c20         NVARCHAR(30)
         ,@c_c21         NVARCHAR(30)
         ,@c_c22         NVARCHAR(30)
         ,@c_c23         NVARCHAR(30)
         ,@c_c24         NVARCHAR(30)
         ,@c_c25         NVARCHAR(30)
         ,@c_c26         NVARCHAR(30)
         ,@c_c27         NVARCHAR(30)
         ,@c_c28         NVARCHAR(30)
         ,@c_c29         NVARCHAR(30)
         ,@c_c30         NVARCHAR(30)

   SELECT @c_Storerkey = ISNULL(RTRIM(OD.Storerkey),'')
   FROM ORDERDETAIL OD (NOLOCK)
   JOIN PACKHEADER PH (NOLOCK) ON OD.OrderKey = PH.OrderKey
   JOIN PACKDETAIL P (NOLOCK) ON PH.PickSlipNo = P.PickSlipNo  
   WHERE P.PickSlipno = @c_PickSlipNo
   
   SELECT @c_c1      = ISNULL(RTRIM(C1.LONG),'') 
         ,@c_c2      = ISNULL(RTRIM(C2.LONG),'')
         ,@c_c3      = ISNULL(RTRIM(C3.LONG),'')
         ,@c_c4      = ISNULL(RTRIM(C4.LONG),'')
         ,@c_c5      = ISNULL(RTRIM(C5.LONG),'')
         ,@c_c6      = ISNULL(RTRIM(C6.LONG),'')
         ,@c_c7      = ISNULL(RTRIM(C7.LONG),'')
         ,@c_c8      = ISNULL(RTRIM(C8.LONG),'')
         ,@c_c9      = ISNULL(RTRIM(C9.LONG),'')
         ,@c_c10     = ISNULL(RTRIM(C10.LONG),'')
         ,@c_c11     = ISNULL(RTRIM(C11.LONG),'')
         ,@c_c12     = ISNULL(RTRIM(C12.LONG),'')
         ,@c_c13     = ISNULL(RTRIM(C13.LONG),'')
         ,@c_c14     = ISNULL(RTRIM(C14.LONG),'')
         ,@c_c15     = ISNULL(RTRIM(C15.LONG),'')
         ,@c_c16     = ISNULL(RTRIM(C16.LONG),'')
         ,@c_c17     = ISNULL(RTRIM(C17.LONG),'')
         ,@c_c18     = ISNULL(RTRIM(C18.LONG),'')
         ,@c_c19     = ISNULL(RTRIM(C19.LONG),'')
         ,@c_c20     = ISNULL(RTRIM(C20.LONG),'')
         ,@c_c21     = ISNULL(RTRIM(C21.LONG),'')
         ,@c_c22     = ISNULL(RTRIM(C22.LONG),'')
         ,@c_c23     = ISNULL(RTRIM(C23.LONG),'')
         ,@c_c24     = ISNULL(RTRIM(C24.LONG),'')
         ,@c_c25     = ISNULL(RTRIM(C25.LONG),'')
         ,@c_c26     = ISNULL(RTRIM(C26.LONG),'')
         ,@c_c27     = ISNULL(RTRIM(C27.LONG),'')
         ,@c_c28     = ISNULL(RTRIM(C28.LONG),'')
         ,@c_c29     = ISNULL(RTRIM(C29.LONG),'')
         ,@c_c30     = ISNULL(RTRIM(C30.LONG),'')
   FROM  CODELKUP C1(NOLOCK) 
	LEFT JOIN Codelkup C2(NOLOCK) ON C2.Listname = 'DNOTECONST' AND c2.code = 'C2' AND C2.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C3(NOLOCK) ON C3.Listname = 'DNOTECONST' AND c3.code = 'C3' AND C3.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C4(NOLOCK) ON C4.Listname = 'DNOTECONST' AND c4.code = 'C4' AND C4.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C5(NOLOCK) ON C5.Listname = 'DNOTECONST' AND c5.code = 'C5' AND C5.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C6(NOLOCK) ON C6.Listname = 'DNOTECONST' AND c6.code = 'C6' AND C6.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C7(NOLOCK) ON C7.Listname = 'DNOTECONST' AND c7.code = 'C7' AND C7.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C8(NOLOCK) ON C8.Listname = 'DNOTECONST' AND c8.code = 'C8' AND C8.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C9(NOLOCK) ON C9.Listname = 'DNOTECONST' AND c9.code = 'C9' AND C9.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C10(NOLOCK) ON C10.Listname = 'DNOTECONST' AND c10.code = 'C10' AND C10.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C11(NOLOCK) ON C11.Listname = 'DNOTECONST' AND c11.code = 'C11' AND C11.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C12(NOLOCK) ON C12.Listname = 'DNOTECONST' AND c12.code = 'C12' AND C12.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C13(NOLOCK) ON C13.Listname = 'DNOTECONST' AND c13.code = 'C13' AND C13.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C14(NOLOCK) ON C14.Listname = 'DNOTECONST' AND c14.code = 'C14' AND C14.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C15(NOLOCK) ON C15.Listname = 'DNOTECONST' AND c15.code = 'C15' AND C15.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C16(NOLOCK) ON C16.Listname = 'DNOTECONST' AND c16.code = 'C16' AND C16.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C17(NOLOCK) ON C17.Listname = 'DNOTECONST' AND c17.code = 'C17' AND C17.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C18(NOLOCK) ON C18.Listname = 'DNOTECONST' AND c18.code = 'C18' AND C18.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C19(NOLOCK) ON C19.Listname = 'DNOTECONST' AND c19.code = 'C19' AND C19.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C20(NOLOCK) ON C20.Listname = 'DNOTECONST' AND c20.code = 'C20' AND C20.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C21(NOLOCK) ON C21.Listname = 'DNOTECONST' AND c21.code = 'C21' AND C21.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C22(NOLOCK) ON C22.Listname = 'DNOTECONST' AND c22.code = 'C22' AND C22.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C23(NOLOCK) ON C23.Listname = 'DNOTECONST' AND c23.code = 'C23' AND C23.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C24(NOLOCK) ON C24.Listname = 'DNOTECONST' AND c24.code = 'C24' AND C24.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C25(NOLOCK) ON C25.Listname = 'DNOTECONST' AND c25.code = 'C25' AND C25.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C26(NOLOCK) ON C26.Listname = 'DNOTECONST' AND c26.code = 'C26' AND C26.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C27(NOLOCK) ON C27.Listname = 'DNOTECONST' AND c27.code = 'C27' AND C27.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C28(NOLOCK) ON C28.Listname = 'DNOTECONST' AND c28.code = 'C28' AND C28.Storerkey = @c_Storerkey
	LEFT JOIN Codelkup C29(NOLOCK) ON C29.Listname = 'DNOTECONST' AND c29.code = 'C29' AND C29.Storerkey = @c_Storerkey
   LEFT JOIN Codelkup C30(NOLOCK) ON C30.Listname = 'DNOTECONST' AND c30.code = 'C30' AND C30.Storerkey = @c_Storerkey 
   WHERE C1.Listname = 'DNOTECONST' AND c1.code = 'C1' AND C1.Storerkey = @c_Storerkey


	SELECT ORDERS.Consigneekey
		,	ORDERS.C_Contact1
		,	ORDERS.C_Contact2
		,	STORER.VAT
		,	ORDERS.C_Address1
		,	ORDERS.C_Phone1
		,	FORMAT(CONVERT(DATE,PACKDETAIL.ADDDATE,102) , 'M/d/yyyy')
		,	PACKDETAIL.LABELNO
		,	ORDERS.EXTERNORDERKEY
		,	PACKDETAIL.SKU                
		,	SKU.DESCR
		,	FORMAT(ORDERDETAIL.UNITPRICE, '#,###')
		,	PACKDETAIL.QTY
		,	ORDERDETAIL.USERDEFINE01
      ,  CAST(FORMAT((PACKDETAIL.QTY * ORDERDETAIL.UNITPRICE), '#,###') AS NVARCHAR) AS Amount
		,	SUM(PACKDETAIL.QTY)
      ,  (SELECT CAST(FORMAT(SUM(P.Qty * OD.UnitPrice), '#,###') AS NVARCHAR)
         FROM ORDERDETAIL OD (NOLOCK)
         JOIN PACKHEADER PH (NOLOCK) ON OD.OrderKey = PH.OrderKey
         JOIN PACKDETAIL P(NOLOCK) ON PH.PickSlipNo = P.PickSlipNo
         WHERE PH.PickSlipNo = @c_PickSlipNo AND P.LabelNo = PACKDETAIL.LabelNo) AS SumAmount        
      --,  (SELECT (FORMAT(SUM(OD.QtyPicked + OD.ShippedQty) * OD.UnitPrice, '#,###'))
      --   FROM ORDERDETAIL OD (NOLOCK)
      --   JOIN PACKHEADER PH (NOLOCK) ON OD.OrderKey = PH.OrderKey
      --   JOIN PACKDETAIL P (NOLOCK) ON PH.PickSlipNo = P.PickSlipNo     
      --   WHERE PH.PickSlipNo = @c_PickSlipNo) AS SumAmount1    
      ,  FORMAT(SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * ORDERDETAIL.UnitPrice, '#,###') AS SumAmount1
		,	@c_c1 AS C1
		,	@c_c2 AS C2      
		,	@c_c3 AS C3
		,	@c_c4 AS C4
		,	@c_c5 AS C5
		,	@c_c6 AS C6
		,	@c_c7 AS C7
		,	@c_c8 AS C8
		,	@c_c9 AS C9
		,	@c_c10 AS C10
		,	@c_c11 AS C11
		,	@c_c12 AS C12
		,	@c_c13 AS C13
		,	@c_c14 AS C14
		,	@c_c15 AS C15
		,	@c_c16 AS C16
		,	@c_c17 AS C17
		,	@c_c18 AS C18
		,	@c_c19 AS C19
		,	@c_c20 AS C20
		,	@c_c21 AS C21
		,	@c_c22 AS C22
		,	@c_c23 AS C23
		,	@c_c24 AS C24
		,	@c_c25 AS C25
		,	@c_c26 AS C26
		,	@c_c27 AS C27
		,	@c_c28 AS C28
		,	@c_c29 AS C29
      ,  @c_c30 AS C30    
	FROM ORDERS (NOLOCK)
	JOIN ORDERDETAIL (NOLOCK) ON ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY
	JOIN STORER (NOLOCK) ON STORER.StorerKey = ORDERS.StorerKey
	JOIN SKU  (NOLOCK)  ON ORDERDETAIL.STORERKEY = SKU.STORERKEY AND ORDERDETAIL.SKU = SKU.SKU
   JOIN PACKHEADER (NOLOCK) ON ORDERS.Orderkey = PACKHEADER.OrderKey
	JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND SKU.SKU = PACKDETAIL.SKU AND SKU.StorerKey = PACKDETAIL.StorerKey
   --create tempt tbl, sub query select cdlkup1-30
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo AND ( PACKDETAIL.CartonNo >= @c_FromCarton ) AND ( PACKDETAIL.CartonNo <= @c_ToCarton )
   AND PackDetail.PickSlipNo = @c_pickslipno
	GROUP BY ORDERS.Consigneekey
		,	ORDERS.C_Contact1
		,	ORDERS.C_Contact2
		,	STORER.VAT
		,	ORDERS.C_Address1
		,	ORDERS.C_Phone1
		,	PACKDETAIL.ADDDATE
		,	PACKDETAIL.LABELNO
		,	ORDERS.EXTERNORDERKEY
		,	PACKDETAIL.SKU
		,	SKU.DESCR
		,	ORDERDETAIL.UNITPRICE
		,	PACKDETAIL.QTY
		,	ORDERDETAIL.USERDEFINE01


END -- procedure    

GO