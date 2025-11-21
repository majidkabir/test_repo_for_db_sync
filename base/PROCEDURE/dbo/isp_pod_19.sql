SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_pod_19                                         */
/* Creation Date:25-JUL-2018                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: POD                                                         */
/*                                                                      */
/* Called By: r_dw_pod_19  WMS-4999-[CN] Dickies POD report             */ 
/*                                                                      */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */
/*                      @c_exparrivaldate = Expected arrival date       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 2023-01-17   mingle    1.1   WMS-21451 - Add showmbol(ML01)          */
/************************************************************************/
CREATE    PROCEDURE [dbo].[isp_pod_19]
        @c_mbolkey NVARCHAR(10), 
        @c_exparrivaldate  NVARCHAR(30) = ''
AS
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_orderkey     NVARCHAR(10),
           @c_type         NVARCHAR(10),
           @n_casecnt      int,
           @n_qty          int,
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
         , @n_TTLCnt                INT     
         , @n_MLine                 INT   
         , @n_CntRec                INT                                                     

   SET @n_Weight              = 0.00                                                                
   SET @n_Cube                = 0.00                                                                
   SET @n_SetMBOLAsOrd        = 0                                                                   
   SET @n_OrderShipAddress    = 0                                                                   
   SET @n_WgtCubeFromPackInfo = 0                                                                   
   SET @n_CountCntByLabelno   = 0                                                                   
   SET @c_Storerkey           = ''    
   SET @n_MLine               = 10                                                             

   SET @c_Brand               = ''                                                                  

   SET @n_PrintAfterPacked    = 0                                                                   
   SET @c_printdate           = REPLACE(CONVERT(NVARCHAR(20),GETDATE(),120),'-','/')                 
   SET @c_printby             = SUSER_NAME()                                                           
   SET @n_TTLCnt              = 0                                                                                                                                  

   CREATE TABLE #POD19
   (mbolkey           NVARCHAR(10)  NULL,
    MbolLineNumber    NVARCHAR(5)   NULL,
    ExternOrderKey    NVARCHAR(30)  NULL,
    Orderkey          NVARCHAR(10)  NULL,
    B_company         NVARCHAR(45)  NULL,   
    EditDate          datetime      NULL,
    c_Company         NVARCHAR(45)  NULL,
    casecnt           INT           NULL,
    Qty               INT           NULL,
    C_Contact         NVARCHAR(60)  NULL,
    C_Address         NVARCHAR(180) NULL,
    leadtime          DATETIME      NULL,
    logo              NVARCHAR(60)  NULL,
    B_Address1        NVARCHAR(45)  NULL,
    B_Contact1        NVARCHAR(30)  NULL,
    B_Phone1          NVARCHAR(18)  NULL,
    B_Fax1            NVARCHAR(18)  NULL,
    Susr2             NVARCHAR(20)  NULL,
    C_Phone           NVARCHAR(36)  NULL,
    c_city            NVARCHAR(45)  NULL,
    STNotes1          NVARCHAR(250) NULL,  
    MCube             FLOAT         NULL,
    STNotes2          NVARCHAR(250) NULL,
	 showmbol			 NVARCHAR(5)   NULL)  

   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM MBOLDETAIL MB WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MB.Orderkey = OH.Orderkey)
   WHERE MB.MBOLKey = @c_MBOLKey
   ORDER BY MB.MBOLLineNumber


    INSERT INTO #POD19
    ( mbolkey,        MbolLineNumber ,    ExternOrderKey,        Orderkey,        b_company,
      EditDate,       c_Company,          C_Contact, 
      C_Address     , C_Phone,            c_city,            
      Qty,            casecnt,            STNotes1 , leadtime,        Logo,
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,
      Susr2,          MCube,               STNotes2,              showmbol)   --ML01     
    SELECT 
      MB.mbolkey,     MD.MbolLineNumber,    MD.ExternOrderKey,    MD.Orderkey,  CASE WHEN ISNULL(ST.logo,'') = '' THEN ST.b_company ELSE '' END,        
      MB.editdate,    OH.c_company,         ltrim(rtrim(isnull(OH.C_Contact1,''))) + ltrim(rtrim(isnull(OH.C_Contact2,''))), 
      ltrim(rtrim(isnull(OH.C_Address1,''))) + ltrim(rtrim(isnull(OH.C_Address2,''))) + 
      ltrim(rtrim(isnull(OH.C_Address3,''))) + ltrim(rtrim(isnull(OH.C_Address4,''))),
      CASE WHEN ISNULL(ST.phone1,'')+ISNULL(ST.phone2,'') <> '' THEN (ISNULL(ST.phone1,'')+ISNULL(ST.phone2,'')) 
      ELSE ISNULL(OH.c_phone1,'')+ISNULL(OH.c_phone2,'') END,ISNULL(OH.c_city,''), 
      SUM(Pd.qty), COUNT(DISTINCT PD.CartonNo), ISNULL(ST.notes1,''),
      CASE WHEN OH.Storerkey = 'DICKIES' THEN MB.Editdate + 1 ELSE DATEADD(day,ISNULL(CAST(c.Short AS int),0),MB.editdate) END,ISNULL(ST.logo,''),
      ST.B_Address1,  ST.B_Contact1,        ST.B_Phone1,          ST.B_fax1,
      ST.Susr2, cast(MD.[cube] as float),ISNULL(ST.notes2,''),
      ISNULL(C1.SHORT,'') AS showmbol	--ML01
    FROM MBOL MB WITH (nolock) 
    JOIN MBOLDETAIL MD  WITH (nolock) ON MB.mbolkey = MD.mbolkey
    JOIN ORDERS OH WITH (nolock) ON MD.orderkey = OH.orderkey
    --LEFT JOIN STORER d WITH (nolock) ON OH.consigneekey = d.storerkey
    JOIN STORER ST WITH (nolock) ON OH.storerkey = ST.storerkey    
    JOIN PICKHEADER PH WITH (NOLOCK) ON PH.orderkey = OH.Orderkey
    JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.pickslipno = PH.Pickheaderkey  
    LEFT JOIN CODELKUP c WITH (nolock) ON c.listname ='CityLdTime' 
                                       AND c.Description = OH.Consigneekey
                                       AND (ISNULL(RTRIM(c.Long),'')= '') OR 
                                             (ISNULL(RTRIM(c.Long),'') <> '' AND ISNULL(RTRIM(c.Long),'') = OH.storerkey)
                                       AND ( (CONVERT( NVARCHAR(20), c.Notes2) = OH.IntermodalVehicle) )   
    LEFT JOIN CODELKUP c1 WITH (nolock) ON c1.listname ='REPORTCFG' 
                                       AND c1.Storerkey = OH.storerkey
                                       AND c1.Long = 'r_dw_pod_19'
                                       AND c1.Code = 'showmbol'   --ML01
    WHERE MB.mbolkey = @c_mbolkey 
    Group by MB.mbolkey,     MD.MbolLineNumber,    MD.ExternOrderKey,    MD.Orderkey,  CASE WHEN ISNULL(ST.logo,'') = '' THEN ST.b_company ELSE '' END,        
      MB.editdate,    OH.c_company,         ltrim(rtrim(isnull(OH.C_Contact1,''))) + ltrim(rtrim(isnull(OH.C_Contact2,''))), 
      ltrim(rtrim(isnull(OH.C_Address1,''))) + ltrim(rtrim(isnull(OH.C_Address2,''))) + 
      ltrim(rtrim(isnull(OH.C_Address3,''))) + ltrim(rtrim(isnull(OH.C_Address4,''))),
      CASE WHEN ISNULL(ST.phone1,'')+ISNULL(ST.phone2,'') <> '' THEN (ISNULL(ST.phone1,'')+ISNULL(ST.phone2,''))
      ELSE ISNULL(OH.c_phone1,'')+ISNULL(OH.c_phone2,'') END,ISNULL(OH.c_city,''), ISNULL(ST.notes1,''),
      CASE WHEN OH.Storerkey = 'DICKIES' THEN MB.Editdate + 1 ELSE DATEADD(day,ISNULL(CAST(c.Short AS int),0),MB.editdate) END,ISNULL(ST.logo,''),
      ST.B_Address1,  ST.B_Contact1,        ST.B_Phone1,          ST.B_fax1,
      ST.Susr2, cast(MD.[cube] as float),ISNULL(ST.notes2,''),
      ISNULL(C1.SHORT,'')	--ML01


   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT Orderkey   
   FROM   #POD19    
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_orderkey    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

      SET @n_CntRec = 0
      SET @n_MLine = 10

      SELECT @n_CntRec = COUNT(1)
      FROM #POD19
      where orderkey = @c_orderkey

      while @n_CntRec<@n_Mline
      BEGIN
       INSERT INTO #POD19
    ( mbolkey,        MbolLineNumber ,    ExternOrderKey,        Orderkey,        b_company,
      EditDate,       c_Company,          C_Contact, 
      C_Address     , C_Phone,            c_city,            
      Qty,            casecnt,            STNotes1 , leadtime,        Logo,
      B_Address1,     B_Contact1,         B_Phone1,              B_Fax1,
      Susr2,          MCube,               STNotes2,              showmbol )  --ML01 
      SELECT TOP 1 mbolkey,MbolLineNumber,ExternOrderKey,@c_orderkey,''
      ,EditDate,c_Company,C_Contact,
      '','','',
      0,'','',leadtime,'',
      '','','','',
      '','','',''
      FROM #POD19
      where orderkey = @c_orderkey

      SET @n_Mline = @n_Mline - 1

      END

   FETCH NEXT FROM CUR_RESULT INTO @c_Orderkey   
   END           

   QUIT:                                                                                             
    SELECT *                                                            
    FROM #POD19
    order by mbolkey,orderkey,MbolLineNumber,casecnt desc,qty desc

    drop table #POD19
END


GO