SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_pod_29                                         */    
/* Creation Date: 29-Dec-2020                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-15979 - Converse MBOL POD                               */    
/*                                                                      */    
/* Called By: r_dw_pod_29                                               */     
/*                                                                      */    
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */    
/*                      @c_exparrivaldate = Expected arrival date       */    
/*                                                                      */    
/* GitLab Version: 1.5                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver. Purposes                                 */ 
/* 2021-11-23   WLChooi   1.1  DevOps Combine Script                    */   
/* 2021-11-23   WLChooi   1.1  WMS-18428 Modify Layout and Logic (WL01) */
/* 2021-12-28   WLChooi   1.2  WMS-18631 Show MBOLKey only based on     */
/*                             condition (WL02)                         */ 
/* 2022-01-25   Mingle    1.3  WMS-18792 Add logic (ML01)               */
/* 2022-01-25   Mingle    1.3  DevOps Combine Script                    */
/* 2022-07-20   WLChooi   1.4  WMS-20286 Revise show MBOLKey logic(WL03)*/
/* 2023-01-04   WLChooi   1.5  WMS-21478 Add input pararm-Username(WL04)*/
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_pod_29]    
        @c_mbolkey NVARCHAR(10),     
        @c_exparrivaldate  NVARCHAR(30) = '',
        @c_RType NVARCHAR(10) = '',
        @c_Username NVARCHAR(250) = ''   --WL04
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @c_orderkey NVARCHAR(10),    
           @c_type     NVARCHAR(10),    
           @n_casecnt  int,    
           @n_qty      int,    
           @n_totalcasecnt int,    
           @n_totalqty     int    
    
   DECLARE @n_TotalWeight  FLOAT                     
         , @n_TotalCube    FLOAT                     
    
         , @n_Weight       FLOAT                     
         , @n_Cube         FLOAT                     
         , @n_SetMBOLAsOrd          INT              
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
         , @c_IncFontSize           NVARCHAR(1)      
         , @n_ShowPageNo            INT       
         , @c_Loadkey               NVARCHAR(10)  
         , @n_MaxLine               INT = 20
         , @n_TotalLine             INT = 0  
         , @n_DummyLine             INT = 0  
         , @n_MaxPage               INT = 0
         , @c_CurrentLine           INT = 0
         , @c_CurrentPage           INT = 0
         , @n_CountPickzone         INT = 0   --WL01
         , @n_CountCertainPickzone  INT = 0   --WL01
         , @c_ShowFlag              NVARCHAR(10)    --WL01
         , @c_ShowMainFlag          NVARCHAR(10)    --WL01
         , @c_DCName                NVARCHAR(250)   --WL01
         , @c_ShipOrderkey          NVARCHAR(20)    --WL01
         , @dt_ShipDate             DATETIME        --WL01
    
   SET @n_Weight              = 0.00                 
   SET @n_Cube                = 0.00                 
   SET @n_SetMBOLAsOrd        = 0                    
   SET @n_OrderShipAddress    = 0                    
   SET @n_WgtCubeFromPackInfo = 0                    
   SET @n_CountCntByLabelno   = 0                    
   SET @c_Storerkey           = ''                   
    
   SET @c_Brand               = ''                   
    
   SET @n_PrintAfterPacked    = 0                                                   
   SET @c_printdate           = REPLACE(CONVERT(NVARCHAR(20),GETDATE(),120),'-','/')
   SET @c_printby             = CASE WHEN ISNULL(@c_Username,'') = '' THEN SUSER_NAME() ELSE CASE WHEN @c_Username LIKE 'ALPHA\%' THEN REPLACE(TRIM(@c_Username),'ALPHA\','') ELSE TRIM(@c_Username) END END   --WL04
    
   SET @n_RemoveEstDelDate    = 0                                                   
   SET @n_RemoveItemName      = 0                                                   
   SET @n_RemoveFax           = 0                                                   
   SET @n_RemovePrintInfo     = 0                                                   
   SET @n_RemoveCartonSumm    = 0                                                                 
   SET @n_ReplIDSWithLFL      = 0                                                   
    
   SET @n_ShowRecDateTimeRmk  = 0                                                   
   SET @c_IncFontSize         = ''                                                  
   SET @n_ShowPageNo          = 0                                                   
    
   CREATE TABLE #POD    
   (  mbolkey           NVARCHAR(20) NULL,    
      MbolLineNumber    NVARCHAR(5)  NULL,    
      Loadkey           NVARCHAR(50) NULL,
      Orderkey          NVARCHAR(10) NULL,    
      Type              NVARCHAR(10) NULL,    
      EditDate          datetime NULL,    
      Company           NVARCHAR(45) NULL,    
      CaseCnt           int NULL,    
      Qty               int NULL,    
      TotalCaseCnt      int NULL,    
      TotalQty          int NULL,      
      leadtime          int NULL,    
      logo              NVARCHAR(60) NULL,    
      B_Address1        NVARCHAR(45) NULL,    
      B_Contact1        NVARCHAR(30) NULL,    
      B_Phone1          NVARCHAR(18) NULL,    
      B_Fax1            NVARCHAR(18) NULL,    
      Susr2             NVARCHAR(20) NULL,    
      MbolLoadkey       NVARCHAR(10) NULL,    
      shipto            NVARCHAR(65) NULL,    
      shiptoadd1        NVARCHAR(45) NULL,    
      shiptoadd2        NVARCHAR(45) NULL,    
      shiptoadd3        NVARCHAR(45) NULL,    
      shiptoadd4        NVARCHAR(45) NULL,    
      shiptocity        NVARCHAR(45) NULL,    
      shiptocontact1    NVARCHAR(30) NULL,    
      shiptocontact2    NVARCHAR(30) NULL,    
      shiptophone1      NVARCHAR(18) NULL,    
      shiptophone2      NVARCHAR(18) NULL,      
      note1a            NVARCHAR(216) NULL,    
      note1b            NVARCHAR(214) NULL,    
      note2a            NVARCHAR(216) NULL,    
      note2b            NVARCHAR(214) NULL,    
      [Weight]          FLOAT NULL,    
      [Cube]            FLOAT NULL,    
      TotalWeight       FLOAT NULL,    
      TotalCube         FLOAT NULL,     
      Domain            NVARCHAR(10)  NULL,
      ConsigneeKey      NVARCHAR(45)
    )   
    
    CREATE TABLE #POD_Final    
   (  mbolkey           NVARCHAR(20) NULL,    
      MbolLineNumber    NVARCHAR(5)  NULL,    
      Loadkey           NVARCHAR(50) NULL,
      Orderkey          NVARCHAR(10) NULL,    
      Type              NVARCHAR(10) NULL,    
      EditDate          datetime NULL,    
      Company           NVARCHAR(45) NULL,    
      CaseCnt           int NULL,    
      Qty               int NULL,    
      TotalCaseCnt      int NULL,    
      TotalQty          int NULL,      
      leadtime          int NULL,    
      logo              NVARCHAR(60) NULL,    
      B_Address1        NVARCHAR(45) NULL,    
      B_Contact1        NVARCHAR(30) NULL,    
      B_Phone1          NVARCHAR(18) NULL,    
      B_Fax1            NVARCHAR(18) NULL,    
      Susr2             NVARCHAR(20) NULL,    
      MbolLoadkey       NVARCHAR(10) NULL,    
      shipto            NVARCHAR(65) NULL,    
      shiptoadd1        NVARCHAR(45) NULL,    
      shiptoadd2        NVARCHAR(45) NULL,    
      shiptoadd3        NVARCHAR(45) NULL,    
      shiptoadd4        NVARCHAR(45) NULL,    
      shiptocity        NVARCHAR(45) NULL,    
      shiptocontact1    NVARCHAR(30) NULL,    
      shiptocontact2    NVARCHAR(30) NULL,    
      shiptophone1      NVARCHAR(18) NULL,    
      shiptophone2      NVARCHAR(18) NULL,      
      note1a            NVARCHAR(216) NULL,    
      note1b            NVARCHAR(214) NULL,    
      note2a            NVARCHAR(216) NULL,    
      note2b            NVARCHAR(214) NULL,    
      [Weight]          FLOAT NULL,    
      [Cube]            FLOAT NULL,    
      TotalWeight       FLOAT NULL,    
      TotalCube         FLOAT NULL,     
      Domain            NVARCHAR(10)  NULL,
      ConsigneeKey      NVARCHAR(45),
      PageNo            INT
    )       
    
   SELECT TOP 1 @c_Storerkey = OH.Storerkey    
   FROM MBOLDETAIL MB WITH (NOLOCK)    
   JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)    
   WHERE MB.MBOLKey = @c_MBOLKey    
   ORDER BY MB.MBOLLineNumber    
    
   SELECT @n_SetMBOLAsOrd        = ISNULL(MAX(CASE WHEN Code = 'SETMBOLASORD' THEN 1 ELSE 0 END),0)    
         ,@n_OrderShipAddress    = ISNULL(MAX(CASE WHEN Code = 'ORDERSHIPADDRESS' THEN 1 ELSE 0 END),0)    
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
         ,@n_ShowPageNo          = ISNULL(MAX(CASE WHEN Code = 'ShowPageNo'THEN 1 ELSE 0 END),0)        
    
   FROM CODELKUP WITH (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_Storerkey    
   AND   Long = 'r_dw_pod_29'    
   AND   ISNULL(Short,'') <> 'N'    

   SELECT @c_IncFontSize = ISNULL(SHORT,'')    
   FROM CODELKUP (NOLOCK)    
   WHERE ListName = 'REPORTCFG'    
   AND   Storerkey= @c_Storerkey    
   AND   Long = 'r_dw_pod_29'    
   AND   CODE = 'IncFontSize'    
 
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

   --WL01 S
   CREATE TABLE #TMP_Pickzone (
      MBOLKey       NVARCHAR(10)
    , Pickzone      NVARCHAR(20)
   )

   INSERT INTO #TMP_Pickzone(MBOLKey, Pickzone)
   SELECT DISTINCT OH.MBOLKey, CONVERT(NVARCHAR, L.LocLevel)   --WL03
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
   JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
   WHERE OH.MBOLKey = @c_mbolkey

   SELECT @n_CountPickzone = COUNT(DISTINCT TP.Pickzone)
   FROM #TMP_Pickzone TP
   WHERE TP.MBOLKey = @c_mbolkey

   SELECT @n_CountCertainPickzone = COUNT(DISTINCT TP.Pickzone)
   FROM #TMP_Pickzone TP
   WHERE TP.MBOLKey = @c_mbolkey
   AND TP.Pickzone IN ('0','5')   --WL03

   SELECT @dt_ShipDate = MBOL.ShipDate
   FROM MBOL (NOLOCK)
   WHERE MBOL.MbolKey = @c_mbolkey

   IF EXISTS (SELECT 1
              FROM #TMP_Pickzone PZ
              WHERE PZ.MBOLKey = @c_mbolkey
              AND PZ.PickZone = '0'   --WL03
              AND @n_CountPickzone = 1)
   BEGIN
      SET @c_ShowFlag = 'N'
      SET @c_ShipOrderkey = @c_mbolkey   --WL02
   END

   IF EXISTS (SELECT 1
              FROM #TMP_Pickzone PZ
              WHERE PZ.MBOLKey = @c_mbolkey
              AND PZ.PickZone = '5'   --WL03
              AND @n_CountPickzone = 1 )
   BEGIN
      SET @c_ShowFlag = 'N'
      SET @c_ShipOrderkey = @c_mbolkey
   END

   IF EXISTS (SELECT 1
              FROM #TMP_Pickzone PZ
              WHERE PZ.MBOLKey = @c_mbolkey
              AND PZ.PickZone IN ('0','5')   --WL03
              AND @n_CountPickzone = 2 
              AND @n_CountPickzone = @n_CountCertainPickzone)
   BEGIN
      SET @c_ShowFlag = 'N'
      SET @c_ShipOrderkey = @c_mbolkey   --WL02
   END

   IF EXISTS (SELECT 1
              FROM #TMP_Pickzone PZ
              JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CONSUBDCPZ'
                                       AND CL.Code = PZ.Pickzone
                                       AND CL.Storerkey = @c_Storerkey
                                       AND CL.UDF01 = '1'
              WHERE PZ.MBOLKey = @c_mbolkey) 
   BEGIN
      SET @c_ShowMainFlag = 'Y'

      SELECT @c_DCName = STUFF((SELECT DISTINCT '\' + RTRIM(ISNULL(CL.Short,'')) 
                                FROM #TMP_Pickzone TP
                                JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'CONSUBDCPZ'
                                                         AND CL.Code = TP.Pickzone
                                                         AND CL.Storerkey = @c_Storerkey
                                                         --AND CL.UDF01 = '1'
                                ORDER BY 1 FOR XML PATH('')),1,1,'' )
   END

   IF ISNULL(@c_ShipOrderkey,'') = ''
   BEGIN 
      SELECT TOP 1 @c_ShipOrderkey = RIGHT(CONVERT(NVARCHAR(10), LP.AddDate, 112), 6) + SUBSTRING(ISNULL(OH.C_Company,''), 1, 4)
      FROM ORDERS OH (NOLOCK)
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
      JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey
      WHERE OH.MBOLKey = @c_mbolkey
   END

   SET @c_ShipOrderkey = UPPER(@c_ShipOrderkey)   --Code 39 barcode only accept capital letter

   SELECT @c_exparrivaldate = CASE WHEN OH.BillToKey = '0000010003' THEN CONVERT(NVARCHAR(10), DATEADD(DAY, C.Short, @dt_ShipDate), 120)  --ML01
                              ELSE CONVERT(NVARCHAR(10), DATEADD(DAY, C1.Short1, @dt_ShipDate), 120) END  --ML01                         
   FROM ORDERS OH (NOLOCK)
   CROSS APPLY (SELECT CASE WHEN ISNUMERIC(MAX(CL.Short)) = 1 THEN MAX(CL.Short) ELSE 0 END AS Short
                FROM CODELKUP CL (NOLOCK) 
                WHERE CL.LISTNAME = 'CONSPGROUP' AND CL.Code = LEFT(OH.C_Company, 4)
                AND CL.Code2 IN (SELECT DISTINCT ColValue FROM dbo.fnc_DelimSplit('\', @c_DCName))
                AND CL.Storerkey = OH.StorerKey) AS C
   CROSS APPLY (SELECT CASE WHEN ISNUMERIC(MAX(CL1.Short)) = 1 THEN MAX(CL1.Short) ELSE 0 END AS Short1
                FROM CODELKUP CL1 (NOLOCK) 
                WHERE CL1.LISTNAME = 'CityLdTime' AND CL1.Code = OH.ConsigneeKey
                AND CL1.Storerkey = OH.StorerKey) AS C1  --ML01
   WHERE OH.MBOLKey = @c_mbolkey
   --WL01 E
    
   INSERT INTO #POD    
    ( mbolkey,        MbolLineNumber ,    Loadkey,               Orderkey,        type,    
      EditDate,       Company,            CaseCnt,               Qty,                          
      TotalCaseCnt,   TotalQty,           leadtime,              Logo,    
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,    
      Susr2,          MbolLoadkey,        ShipTo,                ShipToAdd1,    
      ShipToAdd2,     ShipToAdd3,         ShipToAdd4,            ShipToCity,    
      ShipToContact1, ShipToContact2,     ShipToPhone1,          ShipToPhone2,    
      note1a,         note1b,             note2a,                note2b,    
      Weight,         Cube,               TotalWeight,           TotalCube,                   
      Domain,         ConsigneeKey
      )        
   SELECT DISTINCT    
      a.mbolkey,     '',    c.Loadkey,    '',    c.type,            
      a.editdate,    f.company,           0,                   0,    
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
         (SELECT SUM(ISNULL([Weight],0)) FROM MBOLDETAIL (NOLOCK) WHERE MBOLDETAIL.MbolKey = a.MBOLKey),    
         (SELECT SUM(ISNULL([Cube],0)) FROM MBOLDETAIL (NOLOCK) WHERE MBOLDETAIL.MbolKey = a.MBOLKey),    
         0,    
         0,      
         g.Short   
         ,CASE WHEN @c_showfield='1' AND ISNULL(c.ConsigneeKey,'') <> '' THEN c.ConsigneeKey ELSE '' END    
   FROM MBOL a (nolock) 
   JOIN ORDERS c WITH (nolock) ON a.MBOLKey = c.MBOLKey
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

   SELECT @c_Loadkey = MIN(Loadkey)    
   FROM #POD (nolock)    
        
   WHILE @c_Loadkey IS NOT NULL    
   BEGIN     
      SELECT @c_type = type    
      FROM #POD (nolock)    
      WHERE Loadkey = @c_Loadkey     
          
      SELECT @n_casecnt = 0, @n_qty = 0    
            
      IF EXISTS(SELECT code FROM CODELKUP(NOLOCK) WHERE listname = 'XDOCKTYPE' AND code = @c_type)     
         AND @n_CountCntByLabelno = 0                                                             
      BEGIN    
         SELECT @n_casecnt = COUNT(DISTINCT d.UserDefine01+d.UserDefine02),    
                @n_qty     = SUM(d.qtyallocated + d.ShippedQty + d.QtyPicked)    
         FROM ORDERDETAIL d (nolock)    
         WHERE d.orderkey = @c_orderkey and d.status >= '5'     
         AND d.qtyallocated + d.qtypicked + d.shippedqty > 0    
      END    
      ELSE    
      BEGIN    
         SELECT @n_casecnt = CASE WHEN @n_CountCntByLabelno = 0     
                                  THEN COUNT(DISTINCT PD.Cartonno)    
                                  ELSE COUNT(DISTINCT PD.Labelno)    
                                  END,
                @n_qty     = SUM(PD.qty)  
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo
         WHERE PH.LoadKey = @c_Loadkey
      END    

      SELECT @n_Weight = ISNULL(SUM(ISNULL(PIF.[Weight],0)),0)    
           , @n_Cube   = ISNULL(COUNT(DISTINCT PIF.Cartonno) * 0.083,0)                                                       
      FROM PACKHEADER PH  WITH (NOLOCK)    
      JOIN PACKINFO   PIF WITH (NOLOCK) ON (PH.PickSlipNo = PIF.PickSlipNo)    
      WHERE PH.LoadKey = @c_Loadkey 

      UPDATE #POD    
      SET casecnt  = @n_casecnt,    
          qty      = @n_qty,
          [Weight] = @n_Weight,
          [Cube]   = @n_Cube    
      WHERE Loadkey = @c_Loadkey     
              
      SELECT @c_Loadkey = MIN(Loadkey)    
      FROM #POD (NOLOCK)    
      WHERE Loadkey > @c_Loadkey    
   END    
   
   SELECT @n_totalcasecnt = SUM(casecnt),    
          @n_totalqty     = SUM(qty)     
        , @n_TotalWeight  = SUM([Weight])                                                                
        , @n_TotalCube    = SUM([Cube])                                                                  
   FROM #POD    
       
   UPDATE #POD    
   SET totalcasecnt = @n_totalcasecnt  
     , totalqty     = @n_totalqty    
     , TotalWeight  = @n_TotalWeight                                                                   
     , TotalCube    = @n_TotalCube                                                                       
    
QUIT:   
   /*
   H1 - r_dw_pod_29
   D1 - r_dw_pod_29_1
   D2 - r_dw_pod_29_2
   D3 - r_dw_pod_29_3
   D4 - r_dw_pod_29_4
   */
   IF @c_RType IN ('H1','D2','D3','D4')   
   BEGIN
      SELECT TOP 1 UPPER(mbolkey) AS mbolkey   --For Barcode to display fully (WL04)             
                 , MbolLineNumber       
                 , Loadkey       
                 , Orderkey            
                 , [Type]                
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
                 , UPPER(@c_ShipOrderkey) AS MbolLoadkey   --MbolLoadkey   --WL01   --For Barcode to display fully (WL04)                 
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
                 , ISNULL(@c_exparrivaldate,'')    
                 , @c_printdate, @c_printby                                                                    
                 , @n_RemoveEstDelDate                                                                         
                 , @n_RemoveItemName                                                                           
                 , @n_RemoveFax                                                                                
                 , @n_RemovePrintInfo                                                                          
                 , @n_RemoveCartonSumm                                                                         
                 , @n_ReplIDSWithLFL                                                                           
                 , @n_ShowRecDateTimeRmk                                                                       
                 , @c_IncFontSize                                                                           
                 , @n_ShowPageNo   
                 , Flag     = CASE WHEN @c_ShowFlag = 'N'     THEN N''     ELSE N'集拼' END   --WL01
                 , MainFlag = CASE WHEN @c_ShowMainFlag = 'Y' THEN N'总单' ELSE N''     END   --WL01
                 , DCName   = ISNULL(@c_DCName,'')   --WL01                                                                      
      FROM #POD 
   END   
   ELSE
   BEGIN      
      INSERT INTO #POD_Final(mbolkey, MbolLineNumber, Loadkey, Orderkey, Type, EditDate, Company, CaseCnt, Qty, TotalCaseCnt
                           , TotalQty, leadtime, logo, B_Address1, B_Contact1, B_Phone1, B_Fax1, Susr2, MbolLoadkey, shipto
                           , shiptoadd1, shiptoadd2, shiptoadd3, shiptoadd4, shiptocity, shiptocontact1, shiptocontact2
                           , shiptophone1, shiptophone2, note1a, note1b, note2a, note2b, Weight, Cube, TotalWeight, TotalCube
                           , Domain, ConsigneeKey, PageNo)                                             
      SELECT  @c_ShipOrderkey AS MBOLKey   --mbolkey   --WL01            
            , MbolLineNumber       
            , Loadkey       
            , Orderkey            
            , [Type]                
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
            , (Row_Number() OVER (PARTITION BY MBOLKey ORDER BY MBOLKey, Loadkey) - 1 ) + 1                                                             
      FROM #POD   
      ORDER BY Loadkey 

      --------
      --SELECT @n_TotalLine = COUNT(1)
      --     , @n_MaxPage = MAX(PageNo)
      --FROM #POD_Final P

      --SET @c_CurrentLine = @n_TotalLine

      --SET @n_DummyLine = 12
      --WHILE (@n_DummyLine > 0)
      --BEGIN
      --   SET @c_CurrentLine = @c_CurrentLine + 1

      --   INSERT INTO #POD_Final(mbolkey, MbolLineNumber, Loadkey, Orderkey, Type, EditDate, Company, CaseCnt, Qty, TotalCaseCnt
      --                        , TotalQty, leadtime, logo, B_Address1, B_Contact1, B_Phone1, B_Fax1, Susr2, MbolLoadkey, shipto
      --                        , shiptoadd1, shiptoadd2, shiptoadd3, shiptoadd4, shiptocity, shiptocontact1, shiptocontact2
      --                        , shiptophone1, shiptophone2, note1a, note1b, note2a, note2b, Weight, Cube, TotalWeight, TotalCube
      --                        , Domain, ConsigneeKey, PageNo)
      --   SELECT TOP 1 MBOLKey, NULL, Loadkey, NULL, NULL, EditDate, Company, NULL, NULL, TotalCaseCnt
      --              , TotalQty, leadtime, logo, B_Address1, B_Contact1, B_Phone1, B_Fax1, Susr2, MbolLoadkey, shipto
      --              , shiptoadd1, shiptoadd2, shiptoadd3, shiptoadd4, shiptocity, shiptocontact1, shiptocontact2
      --              , shiptophone1, shiptophone2, note1a, note1b, note2a, note2b, NULL, NULL, TotalWeight, TotalCube
      --              , Domain, ConsigneeKey, @c_CurrentLine
      --   FROM #POD

      --   SET @n_DummyLine = @n_DummyLine - 1
      --END

      --SET @n_MaxLine = 24
      -------------

      --SELECT @n_TotalLine = COUNT(1)
      --     , @n_MaxPage = MAX(PageNo)
      --FROM #POD_Final P

      --IF @n_TotalLine % @n_MaxLine > 3
      --BEGIN
      --   IF @n_TotalLine % @n_MaxLine > 0
      --   BEGIN
      --      SET @n_DummyLine = @n_MaxLine - (@n_TotalLine % @n_MaxLine)
      --      SET @n_DummyLine = @n_DummyLine + 3
      --   END

      --   SET @c_CurrentLine = @n_TotalLine
      --   WHILE (@n_DummyLine > 0)
      --   BEGIN
      --      SET @c_CurrentLine = @c_CurrentLine + 1
         
      --      INSERT INTO #POD_Final(mbolkey, MbolLineNumber, Loadkey, Orderkey, Type, EditDate, Company, CaseCnt, Qty, TotalCaseCnt
      --                           , TotalQty, leadtime, logo, B_Address1, B_Contact1, B_Phone1, B_Fax1, Susr2, MbolLoadkey, shipto
      --                           , shiptoadd1, shiptoadd2, shiptoadd3, shiptoadd4, shiptocity, shiptocontact1, shiptocontact2
      --                           , shiptophone1, shiptophone2, note1a, note1b, note2a, note2b, Weight, Cube, TotalWeight, TotalCube
      --                           , Domain, ConsigneeKey, PageNo)
      --      SELECT TOP 1 MBOLKey, NULL, Loadkey, NULL, NULL, EditDate, Company, NULL, NULL, TotalCaseCnt
      --                 , TotalQty, leadtime, logo, B_Address1, B_Contact1, B_Phone1, B_Fax1, Susr2, MbolLoadkey, shipto
      --                 , shiptoadd1, shiptoadd2, shiptoadd3, shiptoadd4, shiptocity, shiptocontact1, shiptocontact2
      --                 , shiptophone1, shiptophone2, note1a, note1b, note2a, note2b, NULL, NULL, TotalWeight, TotalCube
      --                 , Domain, ConsigneeKey, @c_CurrentLine
      --      FROM #POD_Final PF
         
      --      SET @n_DummyLine = @n_DummyLine - 1
      --   END
      --END

      SELECT UPPER(mbolkey) AS mbolkey   --For Barcode to display fully (WL04)           
           , MbolLineNumber       
           , Loadkey       
           , Orderkey            
           , [Type]                
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
           , UPPER(@c_ShipOrderkey) AS MbolLoadkey   --MbolLoadkey   --WL01   --For Barcode to display fully (WL04)           
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
           , ISNULL(@c_exparrivaldate,'')    
           , @c_printdate, @c_printby                                                                    
           , @n_RemoveEstDelDate                                                                         
           , @n_RemoveItemName                                                                           
           , @n_RemoveFax                                                                                
           , @n_RemovePrintInfo                                                                          
           , @n_RemoveCartonSumm                                                                         
           , @n_ReplIDSWithLFL                                                                           
           , @n_ShowRecDateTimeRmk                                                                       
           , @c_IncFontSize                                                                           
           , @n_ShowPageNo  
           , (Row_Number() OVER (PARTITION BY MBOLKey ORDER BY MBOLKey, CASE WHEN ISNULL(Loadkey,'') = '' THEN 2 ELSE 1 END) - 1 ) / @n_MaxLine + 1  
           , Flag     = CASE WHEN @c_ShowFlag = 'N'     THEN N''     ELSE N'集拼' END   --WL01
           , MainFlag = CASE WHEN @c_ShowMainFlag = 'Y' THEN N'总单' ELSE N''     END   --WL01
           , DCName   = ISNULL(@c_DCName,'')   --WL01   
      FROM #POD_Final
      ORDER BY CASE WHEN ISNULL(Loadkey,'') = '' THEN 2 ELSE 1 END

   END
END   

GO