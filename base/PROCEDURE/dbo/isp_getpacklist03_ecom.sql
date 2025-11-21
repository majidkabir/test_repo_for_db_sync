SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GetPackList03_ecom                             */
/* Creation Date: 15-June-2017                                          */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1913-[TW-ELN] EC PackSummary Report(RCM)                */
/*                                                                      */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_print_packlist_03_main             */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 21-Aug-2017  CSCHONG 1.1   WMS-1913 left join Orderinfo (CS01)       */
/* 28-Aug-2017  CSCHONG 1.2   WMS-1913 -Fix duplicate record (CS01a)    */
/* 05-Feb-2018  Wan01   1.3   WMS-3924 - [TW] E-Land Pack Summar        */
/*                            RCMreport CR                              */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPackList03_ecom] (@c_LoadKey NVARCHAR(10)) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_debug int
   SELECT @b_debug = 0
   
   DECLARE @c_OrderKey        NVARCHAR(10),
           @c_SkuSize        	NVARCHAR(5),
           @c_TempOrderKey    NVARCHAR(10),
           @c_PrevOrderKey    NVARCHAR(10),
           @c_Style           NVARCHAR(20),                                                      
           @c_Color           NVARCHAR(10),                                                       
           @c_PrevStyle       NVARCHAR(20),                                                        
           @c_PrevColor       NVARCHAR(10),                                                        
           @c_SkuSort         NVARCHAR(3),                                                        
           @b_success        	int,
           @n_err            	int,
           @c_errmsg          NVARCHAR(255),
           @n_noofline        INT,
           @c_LPickslipno     NVARCHAR(20),
           @n_Maxline         INT,
           @n_CntLine         INT,
           @c_GetOrdkey       NVARCHAR(20),
           @c_getExtOrdKey    NVARCHAR(20)
         
   

   CREATE TABLE #TempPickSlip03ecom
          (SeqId              INT            NOT NULL  IDENTITY(1,1) PRIMARY KEY--(Wan01)
          ,pickslipno         NVARCHAR(18)   NULL, 
           c_contact1        	NVARCHAR(30)   NULL,
           OrderKey           NVARCHAR(10)   NULL,
           ExternOrderKey  	NVARCHAR(30)   NULL,
           ODUDF03            NVARCHAR(18)   NULL,
           c_Address1        	NVARCHAR(45)   NULL,
           Sku                NVARCHAR(20)   NULL,
           ODUDF01            NVARCHAR(18)   NULL,
           ODUDF02            NVARCHAR(18)   NULL,																	
           ExtendedPrice      FLOAT          NULL,
           TrackingNo         NVARCHAR(30)   NULL,
           Code			      NVARCHAR(30)   NULL,		
           Qty    			   INT            NULL,																
           UDF01              NVARCHAR(150)  NULL,
           CarrierCharges     FLOAT          NULL,
           orderdate          DATETIME       NULL,
           buyerpo            NVARCHAR(20)   NULL,
           PLOC               NVARCHAR(20)   NULL
           )
          
          SET @n_Maxline = 10
          SET @n_CntLine = 1

    
    INSERT INTO #TempPickSlip03ecom
    (
    	ExternOrderKey,
    	orderdate,
    	c_contact1,
    	c_Address1,
    	OrderKey,
    	pickslipno,
    	ODUDF03,
    	Sku,
    	ODUDF01,
    	ODUDF02,
    	Qty,
    	ExtendedPrice,
    	TrackingNo,
    	Code,
    	UDF01,
    	CarrierCharges
    	,buyerpo, PLOC
    )
    SELECT DISTINCT OH.ExternOrderKey, 
		OH.OrderDate, 
		OH.C_contact1, 
		OH.C_Address1, 
		OH.OrderKey, 
		PH.PickHeaderKey, 
		OD.UserDefine03, 
		OD.Sku, 
		OD.UserDefine01, 
		OD.UserDefine02, 
		--OD.ShippedQty + OD.QtyAllocated + OD.QtyPicked QTY,    --(Wan01)
      SUM(PDET.Qty) Qty,                                       --(Wan01)
		OD.ExtendedPrice, 
		OH.TrackingNo, 
		CL.Code, 
		CL.UDF01,
		OI.CarrierCharges,
		ISNULL(OH.BuyerPO,''),
		PDET.Loc		
		FROM PICKHEADER PH WITH (NOLOCK)
		JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey=PH.OrderKey
		JOIN ORDERDETAIL OD WITH (NOLOCK) ON OH.OrderKey=OD.OrderKey
		LEFT OUTER JOIN CODELKUP CL WITH (NOLOCK) ON (OH.ShipperKey=CL.Short AND OH.StorerKey=CL.Storerkey)
												AND (CL.LISTNAME='ECLOGISTP' OR CL.LISTNAME IS NULL)
		LEFT JOIN dbo.orderinfo OI WITH (NOLOCK) ON OH.orderkey=OI.orderkey                                    --CS01
		LEFT JOIN PICKDETAIL PDET WITH (NOLOCK) ON PDET.OrderKey=OD.OrderKey AND PDET.OrderLineNumber=OD.OrderLineNumber
		WHERE  OH.loadkey=@c_LoadKey
		AND OH.Type='ECOM' 
		AND OH.status >='3'
    /*CS01 Start*/
    GROUP BY
       OH.ExternOrderKey, 
		OH.OrderDate, 
		OH.C_contact1, 
		OH.C_Address1, 
		OH.OrderKey, 
		PH.PickHeaderKey, 
		OD.UserDefine03, 
		OD.Sku, 
		OD.UserDefine01, 
		OD.UserDefine02, 
		--OD.ShippedQty + OD.QtyAllocated + OD.QtyPicked ,       --(Wan01)
		OD.ExtendedPrice, 
		OH.TrackingNo, 
		CL.Code, 
		CL.UDF01,
		OI.CarrierCharges,
		ISNULL(OH.BuyerPO,''),
		PDET.Loc		
      ORDER BY PH.PickHeaderKey        --(Wan01)
                  ,OH.Orderkey         --(Wan01)      
                  ,PDET.Loc            --(Wan01)
                  ,OD.Sku              --(Wan01)

		/*CS01 END*/
		
		--SET @c_LPickslipno = ''
		
		--SELECT @c_LPickslipno = MAX(pickslipno)
  --    FROM #TempPickSlip03ecom
      
  --    SELECT TOP 1 @c_GetOrdkey=Orderkey
  --                 ,@c_getExtOrdKey = ExternOrderkey
  --   FROM #TempPickSlip03ecom
  --   WHERE pickslipno=@c_LPickslipno
                  
 
  --  SELECT @n_noofline = COUNT(1)
  --  FROM #TempPickSlip03ecom
  --  WHERE pickslipno=@c_LPickslipno
    
    
  --  SET  @n_CntLine = @n_Maxline - @n_noofline
    
  --  WHILE @n_CntLine <> 0
  --  BEGIN
    	
    	 
		--	 INSERT INTO #TempPickSlip03ecom
		--	 (
  --  			ExternOrderKey,
  --  			orderdate,
  --  			c_contact1,
  --  			c_Address1,
  --  			OrderKey,
  --  			pickslipno,
  --  			ODUDF03,
  --  			Sku,
  --  			ODUDF01,
  --  			ODUDF02,
  --  			Qty,
  --  			ExtendedPrice,
  --  			TrackingNo,
  --  			Code,
  --  			UDF01,
  --  			CarrierCharges
		--	 )
		--	 SELECT @c_getExtOrdKey,NULL,'','',@c_GetOrdkey,@c_LPickslipno,'','','','','','','','','',''
    
		--	 SET @n_CntLine = @n_CntLine - 1
    
  --  END    

   --(Wan01) - START
   SELECT pickslipno        
      ,  c_contact1        
      ,  OrderKey          
      ,  ExternOrderKey    
      ,  ODUDF03           
      ,  c_Address1        
      ,  Sku               
      ,  ODUDF01           
      ,  ODUDF02                                               
      ,  ExtendedPrice = CASE WHEN( SELECT ExtendedPrice
                                    FROM #TempPickSlip03ecom T
                                    WHERE T.PickSlipNo = #TempPickSlip03ecom.PickSlipNo
                                    AND   T.Orderkey   = #TempPickSlip03ecom.Orderkey
                                    AND   T.Sku        = #TempPickSlip03ecom.Sku
                                    AND   T.SeqId >= #TempPickSlip03ecom.SeqId - 1
                                    AND   T.SeqId <  #TempPickSlip03ecom.SeqId
                                  ) = ExtendedPrice 
                              THEN NULL ELSE ExtendedPrice END 
      ,  TrackingNo        
      ,  Code              
      ,  Qty                                             
      ,  UDF01             
      ,  CarrierCharges    
      ,  orderdate         
      ,  buyerpo           
      ,  PLOC     
   --(Wan01) - END
   FROM #TempPickSlip03ecom
   ORDER BY pickslipno,OrderKey,PLOC
   
                                                                                              
   DROP TABLE #TempPickSlip03ecom
 
END

GO