SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_pod_20                                          */
/* Creation Date:14-SEP-2018                                             */
/* Copyright: IDS                                                        */
/* Written by: CSCHONG                                                   */
/*                                                                       */
/* Purpose: POD                                                          */
/*                                                                       */
/* Called By: r_dw_pod_20  WMS-5901                                      */
/*            based on isp_pod_03 to modify                              */ 
/*                                                                       */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                           */
/*                      @c_exparrivaldate = Expected arrival date        */
/*                                                                       */
/* PVCS Version: 1.5                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver. Purposes                                  */
/* 2018-12-15   TLTING    1.1  Bug fix                                   */
/* 2019-03-25   WLCHOOI   1.2  WMS-8282 - Add ExpArrivalTime for         */
/*                                        ALLBirds (WL01)                */
/*************************************************************************/
CREATE PROCEDURE [dbo].[isp_pod_20]
        @c_mbolkey NVARCHAR(10), 
        @c_exparrivaldate  NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_loadkey              NVARCHAR(10),
           @c_type                 NVARCHAR(10),
           @n_casecnt              int,
           @n_qty                  int,
           @n_totalcasecnt         int,
           @n_totalqty             int

   DECLARE @n_TotalWeight          FLOAT                                                                     
         , @n_TotalCube            FLOAT                                                                     

         , @n_Weight                FLOAT                                                                     
         , @n_Cube                  FLOAT                                                                     
         , @n_SetMBOLAsLoad         INT                                                              
         , @n_OrderShipAddress      INT                                                              
         , @n_WgtCubeFromPackInfo   INT                                                              
         , @n_CountCntByLabelno     INT                                                               
         , @c_Storerkey             NVARCHAR(15)                                                     

         , @c_Brand                 NVARCHAR(20)                                                     
         
         , @n_PrintAfterPacked      INT                                                              
         , @c_printdate             NVARCHAR(30)                                                      
         , @c_printby               NVARCHAR(30)                                                        
			, @c_showfield             NVARCHAR(1)                                                      

         , @n_RemoveEstDelDate      INT                                                              
         , @n_RemoveItemName        INT                                                              
         , @n_RemoveFax             INT                                                              
         , @n_RemovePrintInfo       INT                                                              
         , @n_RemoveCartonSumm      INT                                                                             
         , @n_ReplIDSWithLFL        INT                                                               
         , @n_ShowRecDateTimeRmk    INT     
			, @c_getExternOrdkey       NVARCHAR(1000)      
			, @c_GetOrderkey           NVARCHAR(1000) 
         
         ,@n_ShowExpArrivalTime     INT = 0        --WL01                                               

   SET @n_Weight              = 0.00                                                                 
   SET @n_Cube                = 0.00                                                                 
   SET @n_SetMBOLAsLoad       = 0                                                                    
   SET @n_OrderShipAddress    = 0                                                                    
   SET @n_WgtCubeFromPackInfo = 0                                                                    
   SET @n_CountCntByLabelno   = 0                                                                    
   SET @c_Storerkey           = ''                                                                   

   SET @c_Brand               = ''                                                                   

   SET @n_PrintAfterPacked    = 0                                                                    
   SET @c_printdate           = REPLACE(CONVERT(NVARCHAR(20),GETDATE(),120),'-','/')                  
   SET @c_printby             = SUSER_NAME()                                                          

   SET @n_RemoveEstDelDate    = 0                                                                    
   SET @n_RemoveItemName      = 0                                                                    
   SET @n_RemoveFax           = 0                                                                    
   SET @n_RemovePrintInfo     = 0                             
   SET @n_RemoveCartonSumm    = 0                                                                                   
   SET @n_ReplIDSWithLFL      = 0                                                                    

   SET @n_ShowRecDateTimeRmk  = 0                                                                    

   CREATE TABLE #POD
   (mbolkey           NVARCHAR(10) null,
    MbolLineNumber    NVARCHAR(5)  null,
    ExternOrderKey    NVARCHAR(1000) null,
    Orderkey          NVARCHAR(1000) null,
	 LoadKey           NVARCHAR(10) null,
    Type              NVARCHAR(10) null,
    EditDate          datetime null,
    Company           NVARCHAR(45)  null,
    CaseCnt           int       null,
    Qty               int        null,
    TotalCaseCnt      int       null,
    TotalQty          int        null,
    leadtime          int null,
    logo              NVARCHAR(60) null,
    B_Address1        NVARCHAR(45) null,
    B_Contact1        NVARCHAR(30) null,
    B_Phone1          NVARCHAR(18) null,
    B_Fax1            NVARCHAR(18) null,
    Susr2             NVARCHAR(20) null,
    MbolLoadkey       NVARCHAR(10) null,
    shipto            NVARCHAR(65) null,
    shiptoadd1        NVARCHAR(45) null,
    shiptoadd2        NVARCHAR(45) null,
    shiptoadd3        NVARCHAR(45) null,
    shiptoadd4        NVARCHAR(45) null,
    shiptocity        NVARCHAR(45) null,
    shiptocontact1    NVARCHAR(30) null,
    shiptocontact2    NVARCHAR(30) null,
    shiptophone1      NVARCHAR(18) null,
    shiptophone2      NVARCHAR(18) null,
    note1a            NVARCHAR(216) null,
    note1b            NVARCHAR(214) null,
    note2a            NVARCHAR(216) null,
    note2b            NVARCHAR(214) null,
    Weight            FLOAT NULL,
    Cube              FLOAT NULL,
    TotalWeight       FLOAT NULL,
    TotalCube         FLOAT NULL,
    Domain            NVARCHAR(10)  NULL, 
    ConsigneeKey      NVARCHAR(45),
    ExpArrivalTime    NVARCHAR(30) NULL   --WL01  
    ) 

   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM MBOLDETAIL MB WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
   WHERE MB.MBOLKey = @c_MBOLKey
   ORDER BY MB.MBOLLineNumber

   SELECT @n_SetMBOLAsLoad        = ISNULL(MAX(CASE WHEN Code = 'SETMBOLASLOD' THEN 1 ELSE 0 END),0)
         ,@n_WgtCubeFromPackInfo = ISNULL(MAX(CASE WHEN Code = 'WGTCUBEFROMPACKINFO' THEN 1 ELSE 0 END),0)
         ,@n_CountCntByLabelno   = ISNULL(MAX(CASE WHEN Code = 'COUNTCARTONBYLABELNO' THEN 1 ELSE 0 END),0)    
         ,@n_PrintAfterPacked    = ISNULL(MAX(CASE WHEN Code = 'PRINTAFTERPACKED'   THEN 1 ELSE 0 END),0)      
         ,@c_showfield           = ISNULL(MAX(CASE WHEN Code = 'ShowField'   THEN 1 ELSE 0 END),0)          
         ,@n_RemoveEstDelDate    = ISNULL(MAX(CASE WHEN Code = 'RemoveEstDelDate'THEN 1 ELSE 0 END),0)        
         ,@n_RemoveItemName      = ISNULL(MAX(CASE WHEN Code = 'RemoveItemName'  THEN 1 ELSE 0 END),0)        
         ,@n_RemoveFax           = ISNULL(MAX(CASE WHEN Code = 'RemoveFax'       THEN 1 ELSE 0 END),0)        
         ,@n_RemovePrintInfo     = ISNULL(MAX(CASE WHEN Code = 'RemovePrintInfo' THEN 1 ELSE 0 END),0)        
         ,@n_RemoveCartonSumm    = ISNULL(MAX(CASE WHEN Code = 'RemoveCartonSumm'THEN 1 ELSE 0 END),0)        
         ,@n_ReplIDSWithLFL      = ISNULL(MAX(CASE WHEN Code = 'ReplIDSWithLFL'  THEN 1 ELSE 0 END),0)        
         ,@n_ShowRecDateTimeRmk  = ISNULL(MAX(CASE WHEN Code = 'ShowRecDateTimeRmk'THEN 1 ELSE 0 END),0)      
         ,@n_ShowExpArrivalTime  = ISNULL(MAX(CASE WHEN Code = 'ShowExpArrivalTime'THEN 1 ELSE 0 END),0)  --WL01
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'REPORTCFG'
   AND   Storerkey= @c_Storerkey
   AND   Long = 'r_dw_pod_20'
   AND   ISNULL(Short,'') <> 'N'

   IF @n_PrintAfterPacked = 1 
   BEGIN
      IF EXISTS (
                  SELECT 1 
                  FROM MBOLDETAIL MB WITH (NOLOCK)
                  JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
                  WHERE MB.MBOLKey = @c_mbolkey
                  AND OH.Status < '5'
                )
      BEGIN
         GOTO QUIT
      END
   END

   SELECT DISTINCT STORER.Storerkey, CASE WHEN ISNULL(CODELKUP.Code,'') <> '' THEN 
                                 CODELKUP.UDF01 
                            ELSE STORER.SUSR1 END AS SUSR1_UDF01
   INTO #TMP_STORER
   FROM ORDERS (NOLOCK)
   JOIN STORER (NOLOCK) ON ORDERS.Storerkey = STORER.Storerkey
   LEFT JOIN CODELKUP (NOLOCK) ON ORDERS.Storerkey = CODELKUP.Storerkey AND CODELKUP.Listname = 'PODBARCODE'
   WHERE ORDERS.Mbolkey = @c_Mbolkey

    INSERT INTO #POD
    ( mbolkey,        MbolLineNumber ,    ExternOrderKey,        
	   Orderkey,        LoadKey,
      type,           EditDate,       Company,            CaseCnt,               Qty,                      
      TotalCaseCnt,   TotalQty,           leadtime,              Logo,
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,
      Susr2,          MbolLoadkey,        ShipTo,                ShipToAdd1,
      ShipToAdd2,     ShipToAdd3,         ShipToAdd4,            ShipToCity,
      ShipToContact1, ShipToContact2,     ShipToPhone1,          ShipToPhone2,
      note1a,         note1b,             note2a,                note2b,
      Weight,         Cube,               TotalWeight,           TotalCube,                          
      Domain,ConsigneeKey,ExpArrivalTime --WL01
      )    
    SELECT DISTINCT
      a.mbolkey,     '',   (SELECT DISTINCT RTRIM(oh.ExternOrderKey)+', 'FROM ORDERS oh where oh.LoadKey=l.LoadKey FOR XML PATH('')) ,    
		(SELECT DISTINCT RTRIM(oh.OrderKey)+', 'FROM ORDERS oh where oh.LoadKey=l.LoadKey FOR XML PATH('')),    b.LoadKey,        
      c.type,        a.editdate,    f.company,           0,                   0,
      0,             0,                   ISNULL(CAST(e.Short AS int),0),     f.logo,
      f.B_Address1,  f.B_Contact1,        f.B_Phone1,          f.B_fax1,
      f.Susr2,    
         --c=order d=consignee f=storer h=billto+consignee
         CASE WHEN ISNULL(j.Susr1_UDF01,0) & 4 = 4 THEN c.MBOLKey
              ELSE c.Loadkey END AS Mbolloadkey,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Company ELSE h.Company END    
              ELSE  
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   '('+RTRIM(d.Storerkey) + ')' + d.Company
                ELSE 
                CASE WHEN ISNULL(j.Susr1_UDF01,0) & 8 = 8 THEN
                       '('+RTRIM(ISNULL(c.Consigneekey,'')) + '-' + RTRIM(ISNULL(c.Billtokey,'')) +')' + c.C_Company
                ELSE '('+RTRIM(ISNULL(c.Consigneekey,''))+')'+c.C_Company END 
              END 
         END AS Shipto,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address1 ELSE h.Address1 END   
              ELSE  
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address1 ELSE c.C_Address1 END 
         END AS ShipToAdd1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address2 ELSE h.Address2 END    
              ELSE  
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address2 ELSE c.C_Address2 END 
         END AS ShipToAdd2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address3 ELSE h.Address3 END    
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address3 ELSE c.C_Address3 END 
         END AS ShipToAdd3,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Address4 ELSE h.Address4 END    
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Address4 ELSE c.C_Address4 END 
         END AS ShipToAdd4,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_City ELSE h.City END            
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.City ELSE c.C_City END 
         END AS ShipToCity,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact1 ELSE h.Contact1 END    
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Contact1 ELSE c.C_Contact1 END 
         END AS ShipToContact1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Contact2 ELSE h.Contact2 END    
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Contact2 ELSE c.C_Contact2 END 
         END AS ShipToContact2,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone1 ELSE h.Phone1 END        
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Phone1 ELSE c.C_Phone1 END 
         END AS ShipToPhone1,
         CASE WHEN ISNULL(f.SUSR3,0) = 1 THEN CASE WHEN h.Storerkey IS NULL THEN c.C_Phone2 ELSE h.Phone2 END        
              ELSE 
              CASE WHEN ISNULL(j.Susr1_UDF01,0) & 2 = 2 THEN
                   d.Phone2 ELSE c.C_Phone2 END 
         END AS ShipToPhone2, 
         LEFT(CONVERT(NVARCHAR(430),f.Notes1),216) AS note1a,
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes1),217,214) AS note1b,
         LEFT(CONVERT(NVARCHAR(430),f.Notes2),216) AS note2a,
         SUBSTRING(CONVERT(NVARCHAR(430),f.Notes2),217,214) AS note2b, 
         ISNULL(l.Weight,0),
         ISNULL(l.Cube,0),
         0,
         0,
         g.Short
         ,CASE WHEN @c_showfield='1' AND ISNULL(c.ConsigneeKey,'') <> '' THEN c.ConsigneeKey ELSE '' END
         ,ISNULL(e.UDF01,'')        --WL01
    FROM MBOL a (nolock) JOIN MBOLDETAIL b  WITH (nolock) ON a.mbolkey = b.mbolkey
    JOIN ORDERS c WITH (nolock) ON b.orderkey = c.orderkey
	JOIN LoadPlan l WITH (nolock) ON l.LoadKey = c.LoadKey
    LEFT JOIN STORER d WITH (nolock) ON c.consigneekey = d.storerkey
    JOIN STORER f WITH (nolock) ON c.storerkey = f.storerkey    
    LEFT JOIN STORERCONFIG  i WITH (NOLOCK) ON (i.Storerkey = c.Storerkey)
                                            AND(i.Configkey = 'CityLdTimeField')
    LEFT JOIN CODELKUP e WITH (nolock) ON e.listname ='CityLdTime' 
                                       AND ( (i.SValue = '1' AND e.Description = c.C_City) OR
                                             (i.SValue = '2' AND e.Description = f.City) OR
                                             (i.SValue = '3' AND e.Description = c.Consigneekey) OR
                                             (i.SValue = '4' AND e.Description = + RTRIM(c.BillTokey) + RTRIM(c.Consigneekey)) )
                                       AND ( (ISNULL(RTRIM(e.Long),'')= '') OR 
                                             (ISNULL(RTRIM(e.Long),'') <> '' AND ISNULL(RTRIM(e.Long),'') = c.Facility) )
                                       AND CONVERT( NVARCHAR(15), e.Notes) = i.Storerkey
                                       AND ( (CONVERT( NVARCHAR(50), e.Notes2) = c.IntermodalVehicle) OR
                                             (CONVERT( NVARCHAR(50), e.Notes2) = 'ROAD' AND ISNULL(RTRIM(c.IntermodalVehicle),'') = '') )                           
    LEFT JOIN Codelkup g WITH (nolock) ON c.Storerkey = g.Code and g.listname ='STRDOMAIN'  
    LEFT JOIN STORER h WITH (NOLOCK) ON RTRIM(c.Billtokey) + RTRIM(c.Consigneekey) = h.storerkey   
    JOIN #TMP_STORER j WITH (NOLOCK) ON c.Storerkey = j.Storerkey 
    WHERE a.mbolkey = @c_mbolkey


	 SET @n_totalcasecnt = 0
    SET @n_totalqty     = 0
    SET @n_TotalWeight  = 0                                                         
    SET @n_TotalCube    = 0                                                         


    SELECT @c_loadkey = MIN(LoadKey)
    FROM #POD (nolock)
    
    WHILE @c_loadkey IS NOT NULL
    BEGIN 
      SELECT @n_casecnt = 0, @n_qty = 0

         --SELECT @n_casecnt = COUNT(DISTINCT f.cartonno),
         SELECT @n_casecnt = CASE WHEN @n_CountCntByLabelno = 0 
                                  THEN COUNT(DISTINCT f.cartonno)
                                  ELSE COUNT(DISTINCT f.labelno)
                                  END,
                @n_qty     = SUM(f.qty)
         FROM PackHeader e (nolock), PACKDETAIL f (nolock)
         WHERE e.LoadKey = @c_loadkey and e.PickSlipNo = f.pickslipno 
       
      IF @n_SetMBOLAsLoad = 1
      BEGIN
         UPDATE #POD
          SET MBOLKey     = @c_loadkey
            , MbolLoadkey = @c_loadkey
            , Totalcasecnt= @n_casecnt 
            , Totalqty    = @n_qty
         WHERE LoadKey = @c_loadkey
      END

      IF @n_WgtCubeFromPackInfo = 1
      BEGIN
         SET @n_Weight = 0.00
         SET @n_Cube   = 0.00

         SELECT @n_Weight = ISNULL(SUM(ISNULL(PI.Weight,0)),0)
              , @n_Cube   = ISNULL(SUM(ISNULL(PI.Cube,0)),0)                                                       
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKINFO   PI WITH (NOLOCK) ON (PH.PickSlipNo = PI.PickSlipNo)
         WHERE PH.LoadKey = @c_loadkey

         SELECT @n_Weight = ISNULL(CASE WHEN @n_Weight > 0 THEN @n_Weight ELSE SUM(PD.Qty * S.StdGrossWgt) END,0)                                               
               ,@n_Cube   = ISNULL(CASE WHEN @n_Cube > 0 THEN @n_Cube ELSE SUM(PD.Qty * S.StdCube) END,0)      
         FROM PACKHEADER PH WITH (NOLOCK)
         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN SKU        S  WITH (NOLOCK) ON (PD.Storerkey = S.Storerkey) AND (PD.Sku = S.Sku)
         WHERE PH.LoadKey = @c_loadkey
 
         UPDATE #POD
          SET Weight = @n_Weight
            , Cube   = @n_Cube
            , TotalWeight = @n_Weight                                                               
            , TotalCube   = @n_Cube 
         FROM #POD 
         WHERE LoadKey = @c_loadkey
      END

      UPDATE #POD
      SET casecnt = @n_casecnt,
          qty     = @n_qty
      WHERE LoadKey = @c_loadkey 
	  
	  
	  SET @n_totalcasecnt = @n_totalcasecnt + @n_casecnt
      SET @n_totalqty     = @n_totalqty + @n_qty
      SET @n_TotalWeight  = @n_TotalWeight + @n_Weight                                                     
      SET @n_TotalCube    = @n_TotalCube + @n_Cube                                                         


      SELECT @c_loadkey = MIN(LoadKey)
      FROM #POD (nolock)
      WHERE LoadKey > @c_loadkey
    END
    
   IF @n_SetMBOLAsLoad = 0                                                                            
   BEGIN
   
    UPDATE #POD
    SET totalcasecnt = @n_totalcasecnt,
        totalqty     = @n_totalqty
      , TotalWeight  = @n_TotalWeight                                                                 
      , TotalCube    = @n_TotalCube                                                                  
   END

   QUIT:                                                                                              
    


	  --  set @c_getExternOrdkey = (SELECT distinct p2.ExternOrderKey+', 'FROM #POD p2 join #POD on p2.LoadKey=#POD.LoadKey FOR XML PATH('')) 
		-- SET @c_GetOrderkey = (SELECT distinct p2.Orderkey+','FROM #POD p2 join #POD on p2.LoadKey=#POD.LoadKey FOR XML PATH(''))


		 --select @c_getExternOrdkey '@c_getExternOrdkey' , @c_GetOrderkey '@c_GetOrderkey'
	   SELECT  DISTINCT 
            mbolkey      
          , RIGHT('0000'+CONVERT(NVARCHAR(3),ROW_NUMBER() OVER (ORDER BY LoadKey),0),5) AS MbolLineNumber   
          , ExternOrderKey --= (SELECT DISTINCT p2.ExternOrderKey+', 'FROM #POD p2 where p2.LoadKey=#POD.LoadKey FOR XML PATH('')) 
          , Orderkey--= (SELECT DISTINCT p2.Orderkey+', 'FROM #POD p2 where p2.LoadKey=#POD.LoadKey FOR XML PATH(''))       
	       , LoadKey             
          , EditDate        
          , Company         
          , CaseCnt         
          , Qty             
          , TotalCaseCnt    
          , TotalQty        
          , leadtime        
          , logo            
          , B_Address1      
          , B_Contact1      
          , B_Phone1        
          , B_Fax1          
          , Susr2           
          , MbolLoadkey     
          , shipto          
          , shiptoadd1      
          , shiptoadd2      
          , shiptoadd3      
          , shiptoadd4      
          , shiptocity      
          , shiptocontact1   
          , shiptocontact2   
          , shiptophone1    
          , shiptophone2    
          , note1a          
          , note1b          
          , note2a          
          , note2b          
          , Weight          
          , Cube            
          , TotalWeight     
          , TotalCube       
          , Domain          
          , ConsigneeKey
          , ExpArrivalTime             --WL01
         , ISNULL(@c_exparrivaldate,'')
         , @c_printdate, @c_printby                                                                  
         , @n_RemoveEstDelDate                                                                       
         , @n_RemoveItemName                                                                         
         , @n_RemoveFax                                                                              
         , @n_RemovePrintInfo                                                                        
         , @n_RemoveCartonSumm                                                                       
         , @n_ReplIDSWithLFL                                                                         
         , @n_ShowRecDateTimeRmk  
         , @n_ShowExpArrivalTime       --WL01                                                      
    FROM #POD
END

GO