SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_pod_02                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: ECCO POD                                                    */
/*                                                                      */
/* Called By: r_dw_pod_02  SOS#158345                                   */ 
/*                                                                      */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 20-Jul-2010  GTGOH     1.1  SOS#180015 - Insert POD Barcode for      */
/*                             Codelkup.Listname='STRDOMAIN' (GOH01)    */
/* 07-Oct-2010  NJOW01    1.2  191293 - Get address and contact from    */
/*                             storer ECCO.                             */ 
/* 29-Oct-2010  NJOW02    1.3  193653 - ECCO POD add ETA calculation    */
/* 03-Oct-2010  NJOW03    1.4  193653 - Change transportation mode from */
/*                             codelkup.long to codelkup.Notes2         */
/* 20-May-2013  NJOW04    1.5  278666-add mapping to storer.notes1      */
/* 28-Jan-2019  TLTING_ext 1.6  enlarge externorderkey field length      */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_pod_02]
        @c_mbolkey NVARCHAR(10), 
        @c_storerkey NVARCHAR(15) = ''
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
        
   CREATE TABLE #POD
   (mbolkey           NVARCHAR(10) null,
    MbolLineNumber    NVARCHAR(5)  null,
    ExternOrderKey    NVARCHAR(50) null,   --tlting_ext
    Orderkey          NVARCHAR(10) null,
    Loadkey           NVARCHAR(10) null,
    Type              NVARCHAR(10) null,
    EditDate          datetime null,
    C_Company         NVARCHAR(60) null,
    C_City            NVARCHAR(45) null,    
    C_Country         NVARCHAR(30) null,
    C_Contact         NVARCHAR(60)  null,
    C_Address         NVARCHAR(180) null,
    C_Phone           NVARCHAR(36)  null,
    CaseCnt           int       null,
    Qty               int 			null,
    TotalCaseCnt      int       null,
    TotalQty          int 			null,
    Address         NVARCHAR(180) null,
    Phone           NVARCHAR(36)  null,
    Fax             NVARCHAR(36)  null,
    Contact         NVARCHAR(60)  null, 
    Domain          NVARCHAR(10)  null, --GOH01
    B_Address1      NVARCHAR(45)  null,
    B_Contact1      NVARCHAR(30)  null,
    B_Phone1        NVARCHAR(18)  null,
    B_Fax1          NVARCHAR(18) null,
    ExpDeliveryDate datetime null,
    StorerNotes1    NVARCHAR(250) null)  
    
   --NJOW02
   DECLARE @c_storerkey2 NVARCHAR(15), 
           @c_svalue NVARCHAR(10),
           @c_city2 NVARCHAR(45),
           @c_IntermodalVehicle NVARCHAR(30),
           @n_leadtime int,
           @dt_DepartureDate datetime,
           @dt_ExpDeliveryDate datetime
   
   IF ISNULL(@c_storerkey,'') = ''
   BEGIN
      INSERT INTO #POD
      ( mbolkey,            MbolLineNumber ,          ExternOrderKey,             Orderkey,        
        Loadkey,				 Type, 			            EditDate,                   C_Company,          
        C_City,				 C_Country,                C_Contact,                  C_Address,                
        C_Phone,            CaseCnt,                  Qty,                        TotalCaseCnt,               
        TotalQty,           Address,						Phone,							 Fax,												
        Contact,            Domain,                   B_Address1,                  B_Contact1,
        B_Phone1,           B_Fax1,							Storernotes1) 
      SELECT 
        a.mbolkey,           b.MbolLineNumber,         b.ExternOrderKey,  				b.Orderkey,         
        b.loadkey,					 c.type,                   a.editdate,
        ltrim(rtrim(c.consigneekey)) + '('+ ltrim(rtrim(e.Company)) + ')', e.city, e.country, 
        ltrim(rtrim(isnull(e.Contact1,''))) + case len(isnull(e.Contact2,'')) when 0 then '' else ',' end + ltrim(rtrim(isnull(e.Contact2,''))),
        ltrim(rtrim(isnull(e.Address1,''))) + case len(isnull(e.Address2,'')) when 0 then '' else ',' end +   
        ltrim(rtrim(isnull(e.Address2,''))) + case len(isnull(e.Address3,'')) when 0 then '' else ',' end +  
        ltrim(rtrim(isnull(e.Address3,''))) + case len(isnull(e.Address4,'')) when 0 then '' else ',' end +  
        ltrim(rtrim(isnull(e.Address4,''))),  
        ltrim(rtrim(isnull(e.Phone1,''))) + case len(isnull(e.Phone2,'')) when 0 then '' else ',' end + ltrim(rtrim(isnull(e.Phone2,''))),   
        0 ,0  ,0,0,
        d.Address1, d.phone1, d.fax1, d.contact1, 
        isnull(f.Short,''), --GOH01
        g.b_address1, g.b_contact1, g.b_phone1, g.b_fax1, CONVERT(NVARCHAR(250),g.Notes1)
      FROM MBOL a (nolock) JOIN MBOLDETAIL b (nolock) ON a.mbolkey = b.mbolkey
      JOIN ORDERS c (nolock) ON b.orderkey = c.orderkey
      JOIN STORER d (nolock) ON c.storerkey = d.storerkey
      JOIN STORER e (nolock) ON c.consigneekey = e.storerkey
      LEFT JOIN Codelkup f (nolock) ON c.Storerkey = f.Code and f.listname ='STRDOMAIN'   --GOH01
      LEFT JOIN Storer g (nolock) ON (g.Storerkey = 'ECCO')
      WHERE a.mbolkey = @c_mbolkey 
      
      SELECT @c_orderkey = MIN(orderkey)
      FROM #POD (nolock)
            
      WHILE @c_orderkey IS NOT NULL
      BEGIN 
        SELECT @c_type = type
        FROM #POD (nolock)
        WHERE orderkey = @c_orderkey 
        
        --NJOW02 -Start
        SELECT @c_storerkey2 = O.storerkey, 
               @c_svalue = ISNULL(SC.Svalue,''),
               @c_city2 = CASE WHEN SC.Svalue = '1' THEN
                                    O.C_City
                               WHEN SC.Svalue = '2' THEN
                                    S.City
                               WHEN SC.Svalue = '3' THEN
                                    O.Consigneekey
                               ELSE '' END,
               @c_IntermodalVehicle = CASE WHEN O.IntermodalVehicle = '' THEN
                                              'Road'
                                           ELSE O.IntermodalVehicle END,
               @dt_DepartureDate = M.DepartureDate
        FROM ORDERS O (NOLOCK) 
        JOIN STORER S (NOLOCK) ON (O.Consigneekey = S.Storerkey)
        JOIN MBOL M (NOLOCK) ON (O.Mbolkey = M.Mbolkey)
        LEFT JOIN V_StorerConfig2 SC (NOLOCK) ON (O.Storerkey = SC.Storerkey AND SC.Configkey = 'CityLdTimeField')
        WHERE O.Orderkey = @c_orderkey
        
        IF @c_svalue IN('1','2','3')
        BEGIN
           SELECT @n_leadtime = ISNULL(CAST(CL.Short AS int),0)
           FROM CODELKUP CL (NOLOCK)
           WHERE CL.Listname = 'CityLdtime'
           AND CAST(CL.Notes AS NVARCHAR(15)) = @c_Storerkey2
           --AND CL.Long = @c_IntermodalVehicle
           AND CAST(CL.Notes2 AS NVARCHAR(15)) = @c_IntermodalVehicle  --NJOW03
           AND CL.Description = @c_City2
           
           SELECT @dt_ExpDeliveryDate = @dt_DepartureDate + ISNULL(@n_leadtime,0)
           
           UPDATE #POD
           SET ExpDeliveryDate = @dt_ExpDeliveryDate 
           WHERE orderkey = @c_orderkey 
        END
        --NJOW02 End
              
        SELECT @n_casecnt = 0, @n_qty = 0
        
        IF @c_type IN ('EC-MAIN' ,'EC-MAIN-NI')  
        BEGIN
           SELECT @n_casecnt = COUNT(DISTINCT d.UserDefine01+d.UserDefine02),
                  @n_qty     = SUM(d.qtyallocated + d.ShippedQty + d.QtyPicked)
           FROM ORDERDETAIL d (nolock)
           WHERE d.orderkey = @c_orderkey and d.status >= '5' 
           AND d.qtyallocated + d.qtypicked + d.shippedqty > 0
        END
        ELSE
        BEGIN
           SELECT @n_casecnt = COUNT(DISTINCT f.cartonno),
                  @n_qty     = SUM(f.qty)
           FROM PICKHEADER e (nolock), PACKDETAIL f (nolock)
           WHERE e.orderkey = @c_orderkey and e.PickHeaderKey = f.pickslipno 
        END
         
        UPDATE #POD
        SET casecnt = @n_casecnt,
            qty     = @n_qty
        WHERE orderkey = @c_orderkey 
            
        SELECT @c_orderkey = MIN(orderkey)
        FROM #POD (nolock)
        WHERE orderkey > @c_orderkey
      END
      
      SELECT @n_totalcasecnt = SUM(casecnt),
             @n_totalqty     = SUM(qty)
      FROM #POD
      
      UPDATE #POD
      SET totalcasecnt = @n_totalcasecnt,
          totalqty     = @n_totalqty
   END
   ELSE IF EXISTS (SELECT 1
   FROM STORER (nolock) WHERE storerkey = @c_storerkey)
   BEGIN
      INSERT INTO #POD
     ( mbolkey,            MbolLineNumber ,          ExternOrderKey,             Orderkey,  
       Loadkey,				Type,            			  EditDate,                   C_Company,          
       C_City,		  		   C_Country,                C_Contact,                  C_Address,                
       C_Phone,            CaseCnt,                  Qty,                        TotalCaseCnt,               
       TotalQty,           Address,						  Phone,								Fax,												 
       Contact,            Domain,                   B_Address1,                  B_Contact1,
       B_Phone1,           B_Fax1,							Storernotes1)  
     SELECT 
       null,               null,                     null,     									 null,                  
       null, 							 null,                     getdate(),
       ltrim(rtrim(c.storerkey)) + '('+ ltrim(rtrim(c.Company)) + ')', c.City, c.Country,        
       ltrim(rtrim(isnull(c.Contact1,''))) + case len(isnull(c.Contact2,'')) when 0 then '' else ',' end + ltrim(rtrim(isnull(c.Contact2,''))),
       ltrim(rtrim(isnull(c.Address1,''))) + case len(isnull(c.Address2,'')) when 0 then '' else ',' end +   
       ltrim(rtrim(isnull(c.Address2,''))) + case len(isnull(c.Address3,'')) when 0 then '' else ',' end +  
       ltrim(rtrim(isnull(c.Address3,''))) + case len(isnull(c.Address4,'')) when 0 then '' else ',' end +  
       ltrim(rtrim(isnull(c.Address4,''))),  
       ltrim(rtrim(isnull(c.Phone1,''))) + case len(isnull(c.Phone2,'')) when 0 then '' else ',' end + ltrim(rtrim(isnull(c.Phone2,''))),   
       null, null,null,null,null, null,null,null, 
       f.Short, --GOH01
       g.b_address1, g.b_contact1, g.b_phone1, g.b_fax1, CONVERT(NVARCHAR(250),g.Notes1)
       FROM STORER c( nolock)
       LEFT JOIN Codelkup f (nolock) ON c.Storerkey = f.Code and f.listname ='STRDOMAIN'   --GOH01
       LEFT JOIN Storer g (nolock) ON (g.Storerkey = 'ECCO')
       WHERE c.storerkey = @c_Storerkey   
  END
   
  SELECT *
  FROM #POD
END


GO