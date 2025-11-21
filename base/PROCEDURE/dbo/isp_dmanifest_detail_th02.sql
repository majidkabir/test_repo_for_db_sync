SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_dmanifest_detail_th02                          */    
/* Creation Date:  08-JAN-2020                                          */    
/* Copyright: LFL                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:WMS-11525-TH-JDSports Delivery Receipt Report for Ecom Order */    
/*                                                                      */    
/* Input Parameters: @c_mbolkey  - mbolkey                              */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:  Used for report dw = r_dw_dmanifest_detail_th_02             */  
/*      :  Copy from r_dw_dmanifest_detail_th                           */   
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author        Purposes                                  */  
/* 12-MAY-2020  CSCHONG       WMS-13144 revised field mapping (CS01)    */
/************************************************************************/    
CREATE PROC [dbo].[isp_dmanifest_detail_th02] (    
     @c_mbolkey   NVARCHAR(10),
     @c_Type      NVARCHAR(5) = '',
	  @c_Orderkey  NVARCHAR(10) = ''
	   
)    
 AS    
BEGIN    
    SET NOCOUNT ON     
    SET QUOTED_IDENTIFIER OFF     
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @n_continue       INT     
         ,  @c_errmsg         NVARCHAR(255)     
         ,  @b_success        INT     
         ,  @n_err            INT     
         ,  @n_StartTCnt      INT
		 ,  @n_maxline        INT 
		 ,  @n_DELCHRSHIPQTY  INT
		 ,  @c_K2S            NVARCHAR(50)  
		 ,  @n_InvAmt         FLOAT   
    
   SET @n_StartTCnt = @@TRANCOUNT    

   SET @n_maxline = 11
   SET @n_DELCHRSHIPQTY = 0
   SET @c_K2S = ''
   SET @n_InvAmt = 0
    
   WHILE @@TRANCOUNT > 0     
   BEGIN    
      COMMIT TRAN    
   END
   
   --ml01 start
   CREATE TABLE #TEMPDMLBLth02( ROWID   INT IDENTITY (1,1) NOT NULL,
      Orderkey        NVARCHAR(10)      NULL,  
      Storerkey       NVARCHAR(15)      NULL,  
      trackingno      NVARCHAR(30)      NULL,  
      C_Company       NVARCHAR(45)      NULL,  
      C_Address1      NVARCHAR(45)      NULL,  
      C_Address2      NVARCHAR(45)      NULL,  
      ShipQty         INT               NULL,  
      C_COUNTRY       NVARCHAR(45)      NULL,  
      C_City          NVARCHAR(45)      NULL,  
      C_Zip           NVARCHAR(45)      NULL,  
      MbolKey         NVARCHAR(20)      NULL,  
      Extendedprice   FLOAT             NULL,  
      UnitPrice       FLOAT             NULL,  
      ExternOrderkey  NVARCHAR(50)      NULL,  
      Deliverydate    NVARCHAR(11)      NULL,  
      SKU             NVARCHAR(20)      NULL,  
      SDESCR          NVARCHAR(200)     NULL,  
      busr10          NVARCHAR(30)      NULL,  
      Seqno           NVARCHAR(3)       NULL,  
      recgrp          INT               NULL,  
      A1              NVARCHAR(800)     NULL,  
      A2              NVARCHAR(800)     NULL,  
      A10             NVARCHAR(800)     NULL,  
      B               NVARCHAR(800)     NULL,  
      D               NVARCHAR(800)     NULL,  
      F1              NVARCHAR(800)     NULL,  
      F2              NVARCHAR(800)     NULL,  
      F3              NVARCHAR(800)     NULL,  
      F4              NVARCHAR(800)     NULL,  
      F5              NVARCHAR(800)     NULL,  
      F6              NVARCHAR(800)     NULL,  
      G               NVARCHAR(800)     NULL,  
      I1              NVARCHAR(800)     NULL,  
      I2              NVARCHAR(800)     NULL,  
      I3              NVARCHAR(800)     NULL,  
      J               NVARCHAR(800)     NULL,  
      K               NVARCHAR(800)     NULL,  
      L               NVARCHAR(800)     NULL,  
      M               NVARCHAR(800)     NULL,  
      N               NVARCHAR(800)     NULL,  
      P               NVARCHAR(800)     NULL,  
      Q               NVARCHAR(800)     NULL,  
      CD3             NVARCHAR(800)     NULL,  
      CD4             NVARCHAR(800)     NULL,  
      CD8             NVARCHAR(800)     NULL,  
      CD8_1           NVARCHAR(800)     NULL,  
      CD9             NVARCHAR(800)     NULL,  
      CD9_1           NVARCHAR(800)     NULL,  
      CD10            NVARCHAR(800)     NULL,  
      CD10_1          NVARCHAR(800)     NULL,  
      CD11            NVARCHAR(800)     NULL,  
      CD18            NVARCHAR(800)     NULL,  
      CD19            NVARCHAR(800)     NULL,  
      CD20            NVARCHAR(800)     NULL,  
      CD21            NVARCHAR(800)     NULL,  
      CD22            NVARCHAR(800)     NULL,  
      CD23            NVARCHAR(800)     NULL,  
      CD23_1          NVARCHAR(800)     NULL,  
      CD23_2          NVARCHAR(800)     NULL,  
      CD23_3          NVARCHAR(800)     NULL,  
      CD23_4          NVARCHAR(800)     NULL,  
      CD23_5          NVARCHAR(800)     NULL,  
      CD23_6          NVARCHAR(800)     NULL,  
      CD23_7          NVARCHAR(800)     NULL,  
      CD23_8          NVARCHAR(800)     NULL,  
      CD23_9          NVARCHAR(800)     NULL,  
      CD25            NVARCHAR(800)     NULL,  
      CD26            NVARCHAR(800)     NULL,  
      CD27            NVARCHAR(800)     NULL,  
      CD28            NVARCHAR(800)     NULL,
	  labelprice      NVARCHAR(10)      NULL,
	  InvoiceAmount   FLOAT             NULL,
	  OHNotes2        NVARCHAR(800)     NULL,
	  OHNotes2_1      NVARCHAR(800)     NULL,
	  OHNotes2_2      NVARCHAR(800)     NULL,
	  K2              NVARCHAR(800)     NULL, 
	  Orddate         NVARCHAR(11)      NULL,
	  M_VAT           NVARCHAR(18)      NULL,
	  OHUDF03         NVARCHAR(20)      NULL,
	  C               NVARCHAR(800)     NULL, 
	  C_Address3      NVARCHAR(45)      NULL,
	  CD22_1          NVARCHAR(800)     NULL          
   )                                                
                                                
   INSERT INTO #TEMPDMLBLth02(Orderkey      ,   
							  Storerkey     ,   
							  trackingno    ,   
							  C_Company     ,   
							  C_Address1    ,   
							  C_Address2    ,   
							  ShipQty       ,   
							  C_COUNTRY     ,   
							  C_City        ,   
							  C_Zip         ,   
							  MbolKey       ,   
							  Extendedprice ,   
							  UnitPrice     ,   
							  ExternOrderkey,   
							  Deliverydate  ,   
							  SKU           ,   
							  SDESCR        ,   
							  busr10        ,   
							  Seqno         ,   
							  recgrp        ,   
							  A1            ,   
							  A2            ,   
							  A10           ,   
							  B             ,   
							  D             ,   
							  F1            ,   
							  F2            ,   
							  F3            ,   
							  F4            ,   
							  F5            ,   
							  F6            ,   
							  G             ,   
							  I1            ,   
							  I2            ,   
							  I3            ,   
							  J             ,   
							  K             ,   
							  L             ,   
							  M             ,   
							  N             ,   
							  P             ,   
							  Q             ,   
							  CD3           ,   
							  CD4           ,   
							  CD8           ,   
							  CD8_1         ,   
							  CD9           ,   
							  CD9_1         ,   
							  CD10          ,   
							  CD10_1        ,   
							  CD11          ,   
							  CD18          ,   
							  CD19          ,   
							  CD20          ,   
							  CD21          ,   
							  CD22          ,   
							  CD23          ,   
							  CD23_1        ,   
							  CD23_2        ,   
							  CD23_3        ,   
							  CD23_4        ,   
							  CD23_5        ,   
							  CD23_6        ,   
							  CD23_7        ,   
							  CD23_8        ,   
							  CD23_9        ,   
							  CD25          ,   
							  CD26          ,   
							  CD27          ,   
							  CD28          ,
							  labelprice    ,
							  InvoiceAmount ,
							  OHNotes2      ,
							  OHNotes2_1    ,
							  OHNotes2_2    ,
							  K2            ,
							  Orddate       ,
							  M_VAT         ,
							  OHUDF03       ,
							  C             ,
							  C_Address3    ,
							  CD22_1       
 )                       
   SELECT DISTINCT OH.orderkey,OH.storerkey,ISNULL(OH.trackingno,''),OH.c_company,OH.c_address1,OH.c_address2,od.shippedqty,
	OH.c_country,OH.c_city,OH.c_zip,OH.mbolkey,OD.Extendedprice,OD.Unitprice,OH.Externorderkey,convert(nvarchar(11),OH.deliverydate,106),OD.SKU,
	S.descr,S.busr10,'D'+RIGHT('00'+CAST(ROW_NUMBER() OVER (order by OH.mbolkey,OD.sku) as nvarchar(2)),2) ,
	(ROW_NUMBER() OVER (order by OH.mbolkey,OD.sku)-1)/@n_maxline as recrp,
	lbl.A1,lbl.A2,lbl.A10,lbl.B,lbl.D,lbl.F1,lbl.F2,lbl.F3,lbl.F4,lbl.F5,lbl.F6,lbl.G,lbl.I1,lbl.I2,lbl.I3,lbl.J,
	lbl.K,lbl.L,lbl.M,lbl.N,lbl.P,lbl.Q,lbl.CD3,lbl.CD4,lbl.CD8,lbl.CD8_1,lbl.CD9,lbl.CD9_1,lbl.CD10,lbl.CD10_1,
	lbl.CD11,lbl.CD18,lbl.CD19,lbl.CD20,lbl.CD21,lbl.CD22,lbl.CD23,lbl.CD23_1,lbl.CD23_2,lbl.CD23_3,lbl.CD23_4,
	lbl.CD23_5,lbl.CD23_6,lbl.CD23_7,lbl.CD23_8,lbl.CD23_9,lbl.CD25,lbl.CD26,lbl.CD27,lbl.CD28,OH.labelprice,
	OH.invoiceamount,ISNULL(oh.notes2,''), SUBSTRING(OH.notes2,101,100),SUBSTRING(OH.notes2,201,100)
	,lbl.K2,convert(nvarchar(11),OH.Orderdate,106),OH.M_VAT,OH.Userdefine03,lbl.C,OH.c_address3,lbl.CD22_1
	FROM ORDERS OH WITH (NOLOCK)
	JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = OH.Orderkey
	JOIN SKU S WITH (NOLOCK) ON S.storerkey = OD.storerkey and S.SKU = OD.sku
	LEFT JOIN fnc_GetDManifestDETTH02 (@c_mbolkey) lbl ON (lbl.mbolkey = OH.mbolkey)
	where OH.mbolkey =@c_mbolkey
	AND OD.SKU <> 'DELIVERYCHARGES'
	order by OH.mbolkey,OD.sku

   IF @c_Type = 'H'
   BEGIN
      SELECT TOP 1 Mbolkey, Orderkey,externorderkey , Storerkey
	  FROM #TEMPDMLBLth02 
	  where MbolKey=@c_mbolkey
   END  
   ELSE IF @c_Type = 'H2'
   BEGIN

       SET @n_InvAmt = 0

        SELECT @n_DELCHRSHIPQTY = SUM(od.unitprice)
		FROM orders oh (nolock)
		JOIN orderdetail od (nolock) on od.orderkey=oh.orderkey
		WHERE oh.mbolkey =@c_mbolkey
		AND od.sku='DELIVERYCHARGES'

		SELECT @c_K2S = ISNULL(C.UDF01,'')
		FROM CODELKUP C WITH (NOLOCK)
		WHERE C.ListName = 'JDRec' 
		AND C.code = 'K2'

		--set @c_K2S = '0.0654'

		SELECT @n_InvAmt = SUM(OD.shippedqty*od.unitprice)
		FROM orders oh (nolock)
		JOIN orderdetail od (nolock) on od.orderkey=oh.orderkey
		WHERE oh.mbolkey =@c_mbolkey
      AND od.sku<>'DELIVERYCHARGES'    --CS01

      SELECT C_Company,C_Address1,C_Address2,C_City,C_Zip,C_COUNTRY,ExternOrderkey,MbolKey,trackingno,Deliverydate,
	         SKU,SDESCR,busr10,ShipQty,Extendedprice,UnitPrice,seqno,recgrp,A1,A2,A10,B,D,F1,F2,F3,F4,F5,F6,G,I1,
			 I2,I3,J,K,L,M,N,P,Q,labelprice,( @n_InvAmt + @n_DELCHRSHIPQTY) as InvoiceAmount,OHNotes2,OHNotes2_1,OHNotes2_2   --CS01
			 --,rowid/@n_maxline as chkseq
			 ,K2,Orddate,cast ((cast(@c_K2S as float) * ( @n_InvAmt + @n_DELCHRSHIPQTY)) as decimal(10,2)) as M_VAT,      --CS01
           OHUDF03,@n_DELCHRSHIPQTY as DelChgQty,C,c_address3
      FROM #TEMPDMLBLth02
	  where MbolKey=@c_mbolkey
	  Order by rowid

   END
   ELSE
   BEGIN
      SELECT distinct ExternOrderkey,CD3,CD4,CD8,CD8_1,CD9,CD9_1,CD10,CD10_1,CD11,CD18,CD19,CD20,CD21,CD22,CD23,CD23_1,CD23_2,CD23_3,
	         CD23_4,CD23_5,CD23_6,CD23_7,CD23_8,CD23_9,CD25,CD26,CD27,CD28,recgrp,OHUDF03,CD22_1
	  FROM #TEMPDMLBLth02 
	  where MbolKey=@c_mbolkey
	  and Orderkey =@c_Orderkey
  END	  

   QUIT_SP:    
   WHILE @@TRANCOUNT < @n_StartTCnt    
   BEGIN    
      BEGIN TRAN     
   END    
    
   /* #INCLUDE <SPTPA01_2.SQL> */      
   IF @n_continue=3  -- Error Occured - Process And Return      
   BEGIN      
      SELECT @b_success = 0      
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt      
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_dmanifest_detail_th02'      
      --RAISERROR @n_err @c_errmsg     
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_success = 1      
      WHILE @@TRANCOUNT > @n_StartTCnt      
      BEGIN      
         COMMIT TRAN      
      END      
   END    
    
END 

GO