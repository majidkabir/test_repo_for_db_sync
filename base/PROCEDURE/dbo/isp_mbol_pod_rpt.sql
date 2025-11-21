SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_mbol_POD_rpt                                        */
/* Creation Date: 04-MAY-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-4906 - [CN] WelMaxing_EXCEED_POD Report_CR              */
/*        :                                                             */
/* Called By: r_mbol_POD_rpt                                            */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_mbol_POD_rpt]
           @c_MBOLKey   NVARCHAR(10)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

   IF ISNULL(@c_MBOLKey,'') = ''
   BEGIN
   	GOTO QUIT_SP
   END

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_MBPODRPT
      (  RowID       INT IDENTITY (1,1) NOT NULL 
      ,	MBOLKey        NVARCHAR(10)   NULL  DEFAULT('')
      ,  ExtOrdKey      NVARCHAR(30)   NULL  DEFAULT('')
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('')
      ,  C_Company      NVARCHAR(45)   NULL  DEFAULT('')
      ,  ST_Company     NVARCHAR(45)   NULL  DEFAULT('')
      ,  C_Address1     NVARCHAR(100)   NULL  DEFAULT('')
      ,  C_Address2     NVARCHAR(100)   NULL  DEFAULT('')
      ,  ST_Address1    NVARCHAR(100)   NULL  DEFAULT('')
      ,  ST_Address2    NVARCHAR(100)   NULL  DEFAULT('')
      ,  ST_Contact1    NVARCHAR(30)   NULL  DEFAULT('')
      ,  ST_Phone1      NVARCHAR(18)   NULL  DEFAULT('')
      ,  C_Contact1     NVARCHAR(30)   NULL  DEFAULT('')
      ,  C_Phone1       NVARCHAR(18)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  CartonCnt      INT            NULL  DEFAULT(0)
      ,  GrossWgt       FLOAT          NULL  DEFAULT(0)
      ,  PODTotalCube   FLOAT          NULL  DEFAULT(0)
      ,  Storerkey      NVARCHAR(10)   NULL  DEFAULT('')
      ,  consigneekey   NVARCHAR(10)   NULL  DEFAULT('')
		,  loadkey        NVARCHAR(20)   NULL  DEFAULT('')   
     )

           
   INSERT INTO #TMP_MBPODRPT
  (
	-- RowID -- this column value is auto-generated
	MBOLKey,
	ExtOrdKey,
	Orderkey,
	C_Company,
	ST_Company,
	C_Address1,
	C_Address2,
	ST_Address1,
	ST_Address2,
	ST_Contact1,
	ST_Phone1,
	C_Contact1,
	C_Phone1,
	PQty,
	CartonCnt,
	GrossWgt,
	PODTotalCube,
	Storerkey,
	consigneekey,
	loadkey
)

 
   SELECT MBOL.Mbolkey,
         ORDERS.EXTERNORDERKEY,
         ORDERS.Orderkey,   
         ORDERS.C_Company as C_Company,   
         STORER.company as ST_Company,
         ORDERS.C_Address1 as C_Address1, 
         ORDERS.C_Address2 as C_Address2, 
         STORER.Address1 as ST_Address1, 
         STORER.Address2 as ST_Address2, 
         STORER.CONtact1 as ST_Contact1,
         STORER.Phone1 AS ST_phone1,
         --ORDERS.C_Address3 as C_Address3,    
         --ORDERS.C_Address4 as C_Address4,     
     --    ORDERS.C_City as C_City,		   
		   --ORDERS.C_Zip,   
         ORDERS.C_contact1 as C_contact1,   
         ORDERS.C_Phone1 AS c_phone1,   
         QTY = SUM (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked ),
         --STORER.Address3 as Address3,
         --STORER.Address4 as Address4,
         CartonCnt = ISNULL(( 
				SELECT COUNT( DISTINCT PD.PickSlipNo +''+ CONVERT(char(10),PD.CartonNo) )
            FROM  PACKDETAIL PD WITH (NOLOCK)  
       	   JOIN  PackHeader PH WITH (NOLOCK) ON ( PH.PickSlipNO  = PD.PickSlipNO )
            JOIN  ORDERS O WITH (NOLOCK) ON ( PH.LoadKey = O.LoadKey )
            WHERE O.Mbolkey  = @c_MBOLKey
 				AND   ISNULL(O.Consigneekey, '') = ISNULL(ORDERS.Consigneekey, '')), 0),
			/*Item_Type = Left(LTRIM(ORDERDETAIL.SKU), 1),*/
			 GrossWgt = 0 ,--SUM(SKU.STDGROSSWGT * (ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyPicked )),	      
			--ISNULL(CodeLKUP.Short,'') as Short,
			--ProdUnit = ISNULL(RTRIM(LTRIM(CodeLKUP.Long)), ''),
			--Carrier_Company = ISNULL(CARRIER.Company, ''), 
         --STORER.Email1, 
          --STORER.CONtact2 as CONtact2,
         --STORER.Phone2,
         --(SELECT SUM(PODTotalCube) AS PODTotalCube 
         --FROM (SELECT distinct d.CartonNo, CASE WHEN (SUM(d.Qty)=f.CaseCnt) and MAX(e.sku)=MIN(e.sku) THEN
	        --             SUM(e.StdCube*d.Qty) 
         --            ELSE 
         --              (SELECT [Cube] FROM Cartonization (NOLOCK) WHERE CartonizationGroup LIKE 'WelMaxing%' AND UseSequence='1') 
         --            END AS PODTotalCube 
         --     FROM Orders a (NOLOCK)
         --     JOIN Storer b (NOLOCK) ON a.ConsigneeKey=b.Storerkey
         --     JOIN PackHeader c (NOLOCK) ON c.storerkey=a.storerkey and c.Loadkey=a.Loadkey
         --     JOIN Packdetail d (NOLOCK) ON c.PickSlipNo=d.PickSlipNo
         --     JOIN SKU e (NOLOCK) ON e.sku=d.sku and e.storerkey=a.storerkey
         --     JOIN Pack f (NOLOCK) ON e.Packkey=f.Packkey
         --     WHERE a.MbolKey = @c_MBOLKey
         --     GROUP BY f.CaseCnt,d.CartonNo,a.LoadKey) t) PODTotalCube, 
			0 as PODTotalCube,
			 ORDERS.Storerkey ,ORDERS.consigneekey ,ORDERS.loadkey   
   FROM ORDERDETAIL ORDERDETAIL WITH (NOLOCK)   
	JOIN ORDERS  ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )   
	JOIN STORER STORER WITH (NOLOCK) ON ( STORER.StorerKey = ORDERS.StorerKey )   
	JOIN MBOL  MBOL WITH (NOLOCK)   ON ( ORDERDETAIL.Mbolkey = MBOL.Mbolkey )
   JOIN SKU SKU WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey AND ORDERDETAIL.Sku = SKU.Sku)
	LEFT OUTER JOIN STORER CARRIER WITH (NOLOCK) ON ( MBOL.Carrierkey = CARRIER.Storerkey )
	--LEFT OUTER JOIN CodeLKUP CodeLKUP WITH (NOLOCK) ON ( CodeLKUP.ListName = 'SKUFLAG' AND CodeLKUP.Code = RTRIM(SKU.SUSR1)) 
	--LEFT OUTER JOIN CODELKUP CL2 WITH (NOLOCK)  ON (CL2.Listname = 'STRDOMAIN' AND
	--								CL2.Code = ORDERS.StorerKey) 
   WHERE ( MBOL.Mbolkey = @c_MBOLKey ) 
   GROUP BY  MBOL.Mbolkey,
         ORDERS.Storerkey,  
         ORDERS.EXTERNORDERKEY,
         ORDERS.Orderkey,   
         ORDERS.C_Company,   
         ORDERS.C_Address1,   
         ORDERS.C_Address2,   
     --    ORDERS.C_Address3,   
     --    ORDERS.C_Address4,   
		   --ORDERS.C_City,   
		   --ORDERS.C_Zip,   
         ORDERS.C_contact1,   
         ORDERS.C_Phone1,   
		   STORER.company,
         STORER.Address1,     
         STORER.Address2,
         --STORER.Address3,
         --STORER.Address4,
         STORER.CONtact1,
         STORER.PhONe1,ORDERS.consigneekey  ,ORDERS.loadkey  


  
   SELECT  	MBOLKey,
				ExtOrdKey,
				Orderkey,
				C_Company,
				ST_Company,
				C_Address1,
				C_Address2,
				ST_Address1,
				ST_Address2,
				ST_Contact1,
				ST_Phone1,
				C_Contact1,
				C_Phone1,
				PQty,
				CartonCnt,
				GrossWgt,
				PODTotalCube,consigneekey,loadkey
   FROM #TMP_MBPODRPT AS tm

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
       QUIT_SP:
       
END -- procedure

GO