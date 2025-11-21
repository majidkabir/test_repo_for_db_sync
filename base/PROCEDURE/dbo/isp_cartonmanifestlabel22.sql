SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Function:   isp_CartonManifestLabel22                                */
/* Creation Date: 14-Jul-2017                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:                                                             */
/*        : WMS-2285 - CN-Nike SDC Integrated Return Label              */
/*                                                                      */
/* Called By:  r_dw_Carton_Manifest_Label_22                            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 30-Aug-2017  SPChin    1.1   IN00452738 - Bug Fixed                  */
/* 21-Dec-2017  WLCHOOI   1.2   WMS-3661  - Updated mapping for			*/
/*											orderlinenumber(WL01)                  */
/* 27-Mar-2018  CSCHONG   1.3   Add new field (CS01)                    */
/* 08-May-2018  LZG       1.4   INC0224220 - Fixed duplicated SKU (ZG01)*/  
/************************************************************************/

CREATE PROC [dbo].[isp_CartonManifestLabel22]  (
						@c_Pickslipno     NVARCHAR(10)
					  ,@c_StartcartonNo  NVARCHAR(5) = '1'
					  ,@c_EndcartonNo    NVARCHAR(5) 
					  ,@c_type           NVARCHAR(5) 
					  ,@c_orderkey       NVARCHAR(20) = ''
					  ,@n_RecGroup       INT         = 0
)
AS                                  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_InvAmt             FLOAT
         , @n_ShippingHandling   FLOAT
         , @n_NoOfLine           INT
         , @c_ordkey             NVARCHAR(20)
         , @c_sku                NVARCHAR(20)
         , @n_qty                INT
         , @c_ordlineno          NVARCHAR(10)
         , @n_ttlpage            INT
			, @n_Getrecgrp          INT
			, @n_TTLREC             INT	
			    
   SET @n_NoOfLine = 10
   SET @n_ttlpage = 1

	IF ISNULL(@c_StartcartonNo,'') = '' 
	BEGIN
		SET @c_StartcartonNo = '1'
	END
	
	
	IF ISNULL(@c_EndcartonNo,'') = '' 
	BEGIN
		SET @c_EndcartonNo = '99999'
	END

   CREATE TABLE #TMP_CTNMNFDET04 
            (  SeqNo                INT IDENTITY (1,1)
            ,  Orderkey             NVARCHAR(20)
            ,  STO_Company          NVARCHAR(45)
            ,  ORD_Company          NVARCHAR(45)
            ,  C_Phone1             NVARCHAR(18)
            ,  C_zip                NVARCHAR(18)
            ,  C_city               NVARCHAR(45)
            ,  C_Address1           NVARCHAR(45)
            ,  C_Address2           NVARCHAR(45)
            ,  C_Address3           NVARCHAR(45)
            ,  C_Address4           NVARCHAR(45)
            ,  ExtOrdKey            NVARCHAR(20)
            ,  OrdLineNo            NVARCHAR(10)
            ,  style                NVARCHAR(20)
            ,  Color                NVARCHAR(10)
            ,  Size                 NVARCHAR(10)
            ,  SKUDescr             NVARCHAR(120)
            ,  loc                  NVARCHAR(20)
            ,  PQty                 INT DEFAULT(0)
            ,  FDESCR               NVARCHAR(120)
            ,  buyerpo              NVARCHAR(20)
            ,  ORDINFO01            NVARCHAR(30)
            ,  CLRShort             NVARCHAR(80)
            ,  OHUDF03              NVARCHAR(20)
			   ,  CLRNote              NVARCHAR(120)
			   ,  CLRNotes2            NVARCHAR(120)
            ,  RecGroup             INT
            ,  SKU                  NVARCHAR(20)
            ,  TTLPage              INT
            ,  Qrcode               NVARCHAR(4000)    --CS01
            )   

      CREATE TABLE #TMP_CTNMNF22 
            (  Pickslipno     NVARCHAR(10)
				,  StartcartonNo  NVARCHAR(5)
				,  EndcartonNo    NVARCHAR(5)
            ,	Orderkey       NVARCHAR(20)
            ,  Shipperkey     NVARCHAR(30) 
            ,  RecGroup       INT  
            ,  PrnShiplbl     NVARCHAR(1) 
            )   

      CREATE TABLE #TMP_RGRPCTNMNF22
            (  RecGroup             INT
            ,  Pickslipno           NVARCHAR(10)
            ,  Orderkey             NVARCHAR(10)
           -- ,  Cartonno             INT
            )

      INSERT INTO #TMP_RGRPCTNMNF22
            (  RecGroup 
            ,  Pickslipno            
            ,  Orderkey
            )                        
	  SELECT DISTINCT RecGroup   =(Row_Number() OVER (PARTITION BY ORD.Orderkey,PD.sku ORDER BY ORD.Orderkey,  (OD.OrderLineNumber) Asc)-1)/ @n_NoOfLine
	      , PD.PickSlipNo 
         , ORD.Orderkey
        -- , PD.CartonNo
	  FROM PACKDETAIL PD WITH (NOLOCK)
	   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo
	   JOIN ORDERS ORD WITH (NOLOCK) ON ord.OrderKey=PH.OrderKey
	   JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey=ORD.OrderKey
	  --JOIN PICKHEADER PIH WITH (NOLOCK) ON PIH.PickHeaderKey = PH.PickSlipNo AND PIH.OrderKey = PH.OrderKey
	   JOIN PICKDETAIL PID WITH (NOLOCK) ON   PID.OrderKey  = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber
	                                             AND PID.Sku = OD.sku
	   WHERE PD.PickSlipNo = @c_pickslipno 
      AND	PD.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
      
      
      SET @n_ttlpage = 1
      
      SELECT @n_ttlpage = MAX(Recgroup) + 1
      FROM #TMP_RGRPCTNMNF22
      WHERE Pickslipno    = @c_pickslipno
      
                                             
      INSERT INTO #TMP_CTNMNF22
            ( pickslipno
             ,StartcartonNo
             ,EndcartonNo
             ,Orderkey                               
             ,ShipperKey   
             ,RecGroup    
             ,PrnShiplbl       
            ) 
                                                                                      
	  SELECT DISTINCT 
	          PH.PickSlipNo,
	          MAX(PD.CartonNo),
	          MAX(PD.CartonNo),
             ORD.Orderkey,
             ORD.Shipperkey
             ,RG.RecGroup
             ,'N'--CASE WHEN ORD.ShipperKey=C.long THEN 'Y' ELSE 'N' END AS Prnshiplbl    --CS01
	   FROM PACKDETAIL PD WITH (NOLOCK)
	   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo
	   JOIN ORDERS ORD WITH (NOLOCK) ON ord.OrderKey=PH.OrderKey
	 --  LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'NIKEIRL' AND C.Storerkey = ORD.StorerKey AND C.code = ORD.Facility  
	   JOIN #TMP_RGRPCTNMNF22 RG WITH (NOLOCK) ON RG.Orderkey=ORD.OrderKey
	   WHERE PD.PickSlipNo = @c_pickslipno 
     AND	PD.CartonNo BETWEEN CAST(@c_StartcartonNo AS INT) AND CAST(@c_EndcartonNo AS INT)
     GROUP BY PH.PickSlipNo,
             ORD.Orderkey,
             ORD.Shipperkey
             ,RG.RecGroup
             --,CASE WHEN ORD.ShipperKey=C.long THEN 'Y' ELSE 'N' END
     ORDER BY ORD.orderkey ,RG.RecGroup
      
     INSERT INTO  #TMP_CTNMNFDET04 
            (  Orderkey             
            ,  STO_Company          
            ,  ORD_Company          
            ,  C_Phone1             
            ,  C_zip                
            ,  C_city               
            ,  C_Address1           
            ,  C_Address2           
            ,  C_Address3           
            ,  C_Address4           
            ,  ExtOrdKey            
            ,  OrdLineNo            
            ,  style               
            ,  Color                
            ,  Size                 
            ,  SKUDescr             
            ,  loc       
            ,  PQty                 
            ,  FDESCR               
            ,  buyerpo               
            ,  ORDINFO01            
            ,  CLRShort             
            ,  OHUDF03              
			   ,  CLRNote              
			   ,  CLRNotes2            
            ,  RecGroup
            ,  SKU    
            ,  TTLPage    
            ,  Qrcode                              --CS01 
            )              
      SELECT DISTINCT ORD.OrderKey,ISNULL(STO.company,''),ORD.C_Company,ORD.C_Phone1,ORD.c_zip,ISNULL(ORD.c_city,''),ISNULL(ORD.C_Address1,''),
		ISNULL(ORD.C_Address2,''),ISNULL(ORD.C_Address3,''),ISNULL(ORD.C_Address4,''),ORD.ExternOrderKey,
		RIGHT('00000'+CAST((Row_Number() OVER (PARTITION BY ORD.Orderkey ORDER BY ISNULL(S.Style,''), ISNULL(S.Color,'') , ISNULL(S.size,'') Asc)) AS NVARCHAR(5)),5) AS OrdLineNo --OD.OrderLineNumber --WL01
		,ISNULL(S.Style,''), ISNULL(S.Color,'') , ISNULL(S.size,''),s.descr,
		CASE WHEN ISNULL(MIN(TS.LogicalToLoc),'') <> '' THEN ISNULL(MIN(TS.LogicalToLoc),'') ELSE MIN(lli.loc) END,             -- ZG01
		0 AS Pqty,F.Descr,ORD.BuyerPO,ISNULL(OI.OrderInfo01,''),ISNULL(C.Short,''),ISNULL(ORD.UserDefine03,''),
		ISNULL(C.notes,''),ISNULL(C.Notes2,''),
		RecGroup   =(Row_Number() OVER (PARTITION BY ORD.Orderkey ORDER BY ISNULL(S.Style,''), ISNULL(S.Color,'') , ISNULL(S.size,'') Asc)-1)/ @n_NoOfLine --WL01 (Changed from PID.Orderlinenumber to OD.Orderlinenumber)
		,PID.SKU,@n_ttlpage
		,qrcode = C1.Notes + ORD.UserDefine03                                                                  --CS01
		FROM PACKDETAIL PD WITH (NOLOCK)
	   JOIN PACKHEADER PH WITH (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo
	   JOIN ORDERS ORD WITH (NOLOCK) ON ord.OrderKey=PH.OrderKey 
	  --JOIN PICKHEADER PIH WITH (NOLOCK) ON PIH.PickHeaderKey = PH.PickSlipNo AND PIH.OrderKey = PH.OrderKey
	   JOIN PICKDETAIL PID WITH (NOLOCK) ON  PID.CaseID=PD.LabelNo AND PID.Storerkey=PD.StorerKey AND pid.sku=pd.sku
	   JOIN ORDERDETAIL OD WITH (NOLOCK) ON  PID.OrderKey  = OD.OrderKey AND PID.OrderLineNumber = OD.OrderLineNumber
	                                             AND PID.Sku = OD.sku AND PID.Storerkey=OD.StorerKey
	   JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PID.Storerkey AND S.sku = PID.Sku
	   LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=PID.loc AND l.LocationType='DYNPPICK' --AND l.facility = ORD.Facility
	   LEFT JOIN TaskDetail TS WITH (NOLOCK) ON TS.TaskDetailKey = PID.TaskDetailKey AND TS.TaskType='RPF'
	   LEFT JOIN STORER STO (NOLOCK) ON STO.StorerKey=ORD.ShipperKey
	   LEFT JOIN LOtxlocxid LLI WITH (NOLOCK) ON lli.sku =  PD.sku AND lli.loc=PID.loc AND lli.StorerKey=pid.Storerkey
	   LEFT JOIN FACILITY AS f WITH (NOLOCK) ON f.Facility = ORD.Facility
	   JOIN ORDERINFO OI WITH (NOLOCK) ON OI.OrderKey=ORD.OrderKey    
	   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'NIKEIRL' AND C.Storerkey = ORD.StorerKey AND C.code = ORD.Facility  
	   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.listname = 'NIKESDCEX' AND C1.Storerkey=ORD.StorerKey AND C1.code = '001SF'                  --CS01
	   JOIN #TMP_CTNMNF22 CTN22 WITH (NOLOCK) ON CTN22.Orderkey=ORD.OrderKey AND CTN22.Pickslipno=PH.PickSlipNo	--IN00452738
      WHERE ord.orderkey= @c_orderkey
      GROUP BY ORD.OrderKey,ISNULL(STO.company,''),ORD.C_Company,ORD.C_Phone1,ORD.c_zip,ISNULL(ORD.c_city,''),ISNULL(ORD.C_Address1,''),
		ISNULL(ORD.C_Address2,''),ISNULL(ORD.C_Address3,''),ISNULL(ORD.C_Address4,''),ORD.ExternOrderKey,
		--OD.OrderLineNumber,
		ISNULL(S.Style,''), ISNULL(S.Color,'') , ISNULL(S.size,''),s.descr,
		--ISNULL(TS.LogicalToLoc,''),                   -- ZG01
		F.Descr,ORD.BuyerPO,ISNULL(OI.OrderInfo01,''),ISNULL(C.Short,''),ISNULL(ORD.UserDefine03,''),
		ISNULL(C.notes,''),ISNULL(C.Notes2,''),PID.sku,PD.SKU,(C1.Notes + ORD.UserDefine03 )--,PID.qty
      ORDER BY  ord.OrderKey desc 
      
      

      DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
      SELECT DISTINCT orderkey,sku,OrdLineNo 
      from #TMP_CTNMNFDET04          
       
      OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrdKey,@c_sku,@c_ordlineno       
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN            
    
    
    SET @n_qty = 0
    
    SELECT @n_qty = SUM(qty)
    FROM PICKDETAIL (NOLOCK)
    WHERE Orderkey = @c_ordkey
    AND SKU = @c_sku
    --AND OrderLineNumber = @c_ordlineno
    
    
    UPDATE #TMP_CTNMNFDET04
    SET PQty = @n_qty
    WHERE Orderkey=@c_ordkey
    AND SKU = @c_sku
    --AND OrdLineNo=@c_ordlineno
    
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrdKey,@c_sku,@c_ordlineno         
    
	END -- While             
	CLOSE CUR_RowNoLoop            
	DEALLOCATE CUR_RowNoLoop     
		
	
		SELECT @n_Getrecgrp = MAX(RecGroup)
		FROM #TMP_CTNMNFDET04 AS tc
		WHERE orderkey=@c_orderkey
		
		SELECT @n_TTLREC = COUNT(1)
		FROM #TMP_CTNMNFDET04 AS tc
		WHERE orderkey=@c_orderkey
		AND RecGroup = @n_Getrecgrp
		
		
		WHILE @n_TTLREC < @n_NoOfLine
		BEGIN
			INSERT INTO #TMP_CTNMNFDET04
			(
				Orderkey,
				STO_Company,
				ORD_Company,
				C_Phone1,
				C_zip,
				C_city,
				C_Address1,
				C_Address2,
				C_Address3,
				C_Address4,
				ExtOrdKey,
				OrdLineNo,
				style,
				Color,
				[Size],
				SKUDescr,
				loc,
				PQty,
				FDESCR,
				buyerpo,
				ORDINFO01,
				CLRShort,
				OHUDF03,
				CLRNote,
				CLRNotes2,
				RecGroup,
				SKU,
				TTLPage,
				Qrcode
			)
			SELECT TOP 1
			Orderkey,
				STO_Company,
				ORD_Company,
				C_Phone1,
				C_zip,
				C_city,
				C_Address1,
				C_Address2,
				C_Address3,
				C_Address4,
				ExtOrdKey,
				'',
				'',
				'',
				'',
				'',
				'',
				0,
				FDESCR,
				buyerpo,
				ORDINFO01,
				CLRShort,
				OHUDF03,
				CLRNote,
				CLRNotes2,
				RecGroup,
				SKU,
				TTLPage,
				Qrcode
			FROM #TMP_CTNMNFDET04 AS tc
			WHERE orderkey = @c_orderkey
			AND RecGroup = @n_Getrecgrp
			
			SET @n_TTLREC = @n_TTLREC + 1
		END
		     
      
       IF @c_type = 'H1' GOTO TYPE_H1
       IF @c_type = 'D_PST' GOTO TYPE_D_PLIST
       IF @c_type = 'D_SPL' GOTO TYPE_D_SPLBL
      
      TYPE_H1: 
      SELECT * FROM #TMP_CTNMNF22
      ORDER BY Orderkey, RecGroup
      
      DROP TABLE #TMP_CTNMNF22

      GOTO QUIT
   TYPE_D_PLIST:

      SELECT CTDET04.orderkey
            ,CTDET04.STO_Company
            ,CTDET04.ORD_Company
            ,CTDET04.C_Phone1
            ,CTDET04.C_zip
            ,CTDET04.C_city
            ,CTDET04.C_Address1
            ,CTDET04.C_Address2
            ,CTDET04.C_Address3
            ,CTDET04.C_Address4
            ,CTDET04.ExtOrdKey
            ,CTDET04.OrdLineNo
			   ,CTDET04.style 
			   ,CTDET04.Color	 
			   ,CTDET04.Size	     
			   ,CTDET04.skudescr
			   ,CTDET04.loc
			   ,CTDET04.PQTY
			   ,CTDET04.FDESCR
			   ,CTDET04.BuyerPO
			   ,CTDET04.ORDINFO01
			   ,CTDET04.RecGroup
			   ,CTDET04.TTLPage
			   ,CTDET04.OHUDF03     --CS01
			   ,CTDET04.Qrcode       --CS01
	   FROM #TMP_CTNMNFDET04 CTDET04
      WHERE Orderkey = @c_orderkey
      AND CTDET04.RecGroup=@n_RecGroup
      ORDER BY Orderkey,seqno

      --DROP TABLE ##TMP_CTNMNFDET04
      GOTO QUIT

   TYPE_D_SPLBL:

	    SELECT DISTINCT CTDET04.orderkey
	         ,CTDET04.buyerpo
            ,CTDET04.CLRShort
            ,CTDET04.ORD_Company
            ,CTDET04.C_Phone1
           -- ,CTDET04.C_zip
            ,CTDET04.C_city
            ,CTDET04.C_Address1
            ,CTDET04.C_Address2
            ,CTDET04.C_Address3
            ,CTDET04.C_Address4
            ,CTDET04.OHUDF03
            ,CTDET04.CLRNote
			   ,CTDET04.CLRNotes2 
			   ,CTDET04.RecGroup
			   ,CONVERT(NVARCHAR(14),DATEPART(YEAR,GETDATE() + 30)) AS YearExpDate
			   ,CONVERT(NVARCHAR(2),DATEPART(month,GETDATE() + 30)) AS MonExpDate
			   ,CONVERT(NVARCHAR(2),DATEPART(day,GETDATE() + 30)) AS DayExpDate
	   FROM #TMP_CTNMNFDET04 CTDET04
      WHERE RecGroup = @n_RecGroup
      AND CTDET04.RecGroup=@n_RecGroup
      ORDER BY Orderkey
      
      DROP TABLE #TMP_CTNMNFDET04
      GOTO QUIT 
   QUIT:
   
   
END

GO