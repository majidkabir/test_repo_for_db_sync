SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_pod_35                                         */
/* Creation Date:26-JUL-2023                                            */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-23147CN-GBMAX POD report CR                             */
/*                                                                      */
/* Called By: r_dw_pod_35                                               */
/*           copy from r_dw_pod_01                                      */
/*                                                                      */
/* Parameters: (Input)  @c_mbolkey   = MBOL No                          */
/*                      @c_storerkey = Storer Code                      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver. Purposes                                 */
/* 26-Jul-2023  CSCHONG   1.0  Devops Scripts Combine                   */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_pod_35]
        @c_mbolkey NVARCHAR(10),
        @c_storerkey NVARCHAR(15) = '',
        @c_exparrivaldate  NVARCHAR(30) = ''
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
           @n_totalqty     int,
           @c_RemoveCol NVARCHAR(10)   

   CREATE TABLE #POD
   (mbolkey           NVARCHAR(10) null,
    MbolLineNumber    NVARCHAR(5)  null,
    ExternOrderKey    NVARCHAR(50) null,  --tlting_ext
    Orderkey          NVARCHAR(10) null,
    Type              NVARCHAR(10) null,
    EditDate          datetime null,
    C_Company         NVARCHAR(60)  null,
    C_Contact         NVARCHAR(60)  null,
    C_Address         NVARCHAR(180) null,
    C_Phone           NVARCHAR(36)  null,
    CaseCnt           int        null,
    Qty               int        null,
    TotalCaseCnt      int        null,
    TotalQty          int        null,
    Address           NVARCHAR(180) null,
    Phone             NVARCHAR(36)  null,
    Fax               NVARCHAR(36)  null,
    Contact           NVARCHAR(60)  null,
    leadtime          int null,
    Domain            NVARCHAR(10)  null, 
    Notes1            NVARCHAR(250) NULL, 
    Transportmode     NVARCHAR(100) NULL,  
    SUSR1             NVARCHAR(20)  NULL,  
    RemoveCol         NVARCHAR(10)  NULL) 


    SELECT @c_RemoveCol = ISNULL(CL.Short,'N')
    FROM CODELKUP CL (NOLOCK)
    WHERE CL.Listname = 'REPORTCFG' AND CL.Code = 'RemoveCol'
    AND CL.Storerkey IN (SELECT Storerkey FROM ORDERS (NOLOCK) WHERE Mbolkey = @c_mbolkey)
    AND CL.Long = 'r_dw_pod_35'

   IF ISNULL(@c_storerkey,'') = ''
   BEGIN
      IF ( SELECT COUNT(DISTINCT ISNULL(ORDERS.IntermodalVehicle,'')) 
           FROM MBOLDETAIL (NOLOCK)
           JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey
           WHERE MBOLDETAIL.Mbolkey = @c_mbolkey ) > 1
      BEGIN
         INSERT INTO #POD (Transportmode, Contact) VALUES ('TRANSPORT MODE ERROR','The MBOL Is Not Allowed More Than One Transport Mode')
      END
      ELSE
      BEGIN

         IF @c_RemoveCol = 'Y'
         BEGIN
            INSERT INTO #POD
            ( mbolkey,            MbolLineNumber ,          ExternOrderKey,             Orderkey,
              Type,               EditDate,                 C_Company,                  C_Contact,
              C_Address,          C_Phone,                  CaseCnt,                    Qty,
              TotalCaseCnt,       TotalQty,                 Address,                    Phone,
              Fax,                Contact,                  leadtime,                   Domain,     notes1, Transportmode, SUSR1, RemoveCol) 
            SELECT
              a.mbolkey,           b.MbolLineNumber,         b.ExternOrderKey,            b.Orderkey,
              c.type,                     a.editdate,
              ltrim(rtrim(c.consigneekey)) + '('+ ltrim(rtrim(c.C_Company)) + ')',
              ltrim(rtrim(isnull(c.C_Contact1,''))) + ltrim(rtrim(isnull(c.C_Contact2,''))),
              ltrim(rtrim(isnull(c.C_Address1,''))) + ltrim(rtrim(isnull(c.C_Address2,''))) + ltrim(rtrim(isnull(c.C_Address3,''))) + ltrim(rtrim(isnull(c.C_Address4,''))),
              LTRIM(RTRIM(ISNULL(c.C_Phone1,''))) + CASE WHEN LTRIM(RTRIM(ISNULL(c.C_Phone2,''))) = '' THEN '' ELSE '/' + LTRIM(RTRIM(ISNULL(c.C_Phone2,''))) END,   
              0 ,0  ,0,0,
              d.Address1, d.phone1, d.fax1, d.contact1, isnull(cast(e.Short as int),0),
              isnull(f.Short,''), 
              CONVERT(NVARCHAR(250), g.notes1), 
              CONVERT(NVARCHAR(100), h.notes), 
              i.SUSR1,
              ISNULL(CL.Short,'N') AS RemoveCol  
            FROM MBOL a (nolock) JOIN MBOLDETAIL b (nolock) ON a.mbolkey = b.mbolkey
            JOIN ORDERS c (nolock) ON b.orderkey = c.orderkey
            LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Code = 'RemoveCol' AND CL.Storerkey = c.StorerKey
                                          AND CL.Long = 'r_dw_pod_35' 
            LEFT JOIN STORER d (nolock) ON c.storerkey = d.consigneefor AND d.type = '9' AND d.Facility = c.Facility  
            LEFT JOIN Codelkup e (nolock) ON c.Consigneekey = e.Description AND c.Storerkey = CONVERT(NVARCHAR(15),e.Notes)
                      AND c.IntermodalVehicle = CONVERT(NVARCHAR(15),e.Notes2) and e.listname ='CityLdTime'
            LEFT JOIN Codelkup f (nolock) ON c.Storerkey = f.Code and f.listname ='STRDOMAIN'  
            LEFT JOIN STORER g (nolock) ON c.consigneekey = g.storerkey  
            LEFT JOIN Codelkup h (nolock) ON c.IntermodalVehicle = h.code and h.listname = 'TRANSMETH' 
            JOIN STORER i (nolock) ON c.storerkey = i.storerkey
            WHERE a.mbolkey = @c_mbolkey
         END
         ELSE
         BEGIN
            INSERT INTO #POD
            ( mbolkey,            MbolLineNumber ,          ExternOrderKey,             Orderkey,
              Type,               EditDate,                 C_Company,                  C_Contact,
              C_Address,          C_Phone,                  CaseCnt,                    Qty,
              TotalCaseCnt,       TotalQty,                 Address,                    Phone,
              Fax,                Contact,                  leadtime,                   Domain,     notes1, Transportmode, SUSR1, RemoveCol) 
            SELECT
              a.mbolkey,           b.MbolLineNumber,         b.ExternOrderKey,            b.Orderkey,
              c.type,                     a.editdate,
              ltrim(rtrim(c.consigneekey)) + '('+ ltrim(rtrim(c.C_Company)) + ')',
              ltrim(rtrim(isnull(c.C_Contact1,''))) + ltrim(rtrim(isnull(c.C_Contact2,''))),
              ltrim(rtrim(isnull(c.C_Address1,''))) + ltrim(rtrim(isnull(c.C_Address2,''))) + ltrim(rtrim(isnull(c.C_Address3,''))) + ltrim(rtrim(isnull(c.C_Address4,''))),
              ltrim(rtrim(isnull(c.C_Phone1,''))) + ltrim(rtrim(isnull(c.C_Phone2,''))), 0 ,0  ,0,0,
              d.Address1, d.phone1, d.fax1, d.contact1, isnull(cast(e.Short as int),0),
              isnull(f.Short,''), 
              CONVERT(NVARCHAR(250), g.notes1), 
              CONVERT(NVARCHAR(100), h.notes), 
              i.SUSR1,
              ISNULL(CL.Short,'N') AS RemoveCol   
            FROM MBOL a (nolock) JOIN MBOLDETAIL b (nolock) ON a.mbolkey = b.mbolkey
            JOIN ORDERS c (nolock) ON b.orderkey = c.orderkey
            LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Code = 'RemoveCol' AND CL.Storerkey = c.StorerKey
                                          AND CL.Long = 'r_dw_pod_35'   
            LEFT JOIN STORER d (nolock) ON c.storerkey = d.consigneefor AND d.type = '9'   
            LEFT JOIN Codelkup e (nolock) ON c.Consigneekey = e.Description AND c.Storerkey = CONVERT(NVARCHAR(15),e.Notes) 
                      AND c.IntermodalVehicle = CONVERT(NVARCHAR(15),e.Notes2) and e.listname ='CityLdTime'
            LEFT JOIN Codelkup f (nolock) ON c.Storerkey = f.Code and f.listname ='STRDOMAIN' 
            LEFT JOIN STORER g (nolock) ON c.consigneekey = g.storerkey  
            LEFT JOIN Codelkup h (nolock) ON c.IntermodalVehicle = h.code and h.listname = 'TRANSMETH' 
            JOIN STORER i (nolock) ON c.storerkey = i.storerkey
            WHERE a.mbolkey = @c_mbolkey
         END

         SELECT @c_orderkey = MIN(orderkey)
         FROM #POD (nolock)

         WHILE @c_orderkey IS NOT NULL
         BEGIN
           SELECT @c_type = type
           FROM #POD (nolock)
           WHERE orderkey = @c_orderkey

           SELECT @n_casecnt = 0, @n_qty = 0

           IF @c_type = 'XDOCK'
           BEGIN
              SELECT @n_casecnt = COUNT(DISTINCT d.UserDefine01+d.UserDefine02),
                     @n_qty     = SUM(d.qtyallocated + d.ShippedQty + d.QtyPicked)
              FROM ORDERDETAIL d (nolock) 
              WHERE d.orderkey = @c_orderkey and d.status >= '5'
              AND d.qtyallocated + d.qtypicked + d.shippedqty > 0
           END
           ELSE
           BEGIN

              SELECT @n_qty     = SUM(f.qty)
              FROM PICKDETAIL f (nolock)
              WHERE f.orderkey = @c_orderkey

              SELECT @n_casecnt = ISNULL(m.CtnCnt1,0)+ISNULL(m.CtnCnt2,0)+ISNULL(m.CtnCnt3,0)+ISNULL(m.CtnCnt4,0)+ISNULL(m.CtnCnt5,0)
                FROM MBOLDETAIL m (NOLOCK)
              WHERE m.OrderKey = @c_orderkey
              AND m.MbolKey = @c_mbolkey
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
   END --storerkey=''
   ELSE IF EXISTS (SELECT 1
   FROM STORER (nolock) WHERE storerkey = @c_storerkey AND consigneefor = '18328')
   BEGIN
      INSERT INTO #POD
     ( mbolkey,            MbolLineNumber ,          ExternOrderKey,             Orderkey,
       Type,               EditDate,                 C_Company,                  C_Contact,
       C_Address,          C_Phone,                  CaseCnt,                    Qty,
       TotalCaseCnt,       TotalQty,                 Address,                    Phone,
       Fax,                Contact,                  leadtime,                   Domain,   Notes1, Transportmode, SUSR1)  
     SELECT
       null,               null,                     null,                                 null,
       null,                       getdate(),
       ltrim(rtrim(c.storerkey)) + '('+ ltrim(rtrim(c.Company)) + ')',
       ltrim(rtrim(isnull(c.Contact1,''))) + ltrim(rtrim(isnull(c.Contact2,''))),
       ltrim(rtrim(isnull(c.Address1,''))) + ltrim(rtrim(isnull(c.Address2,''))) + ltrim(rtrim(isnull(c.Address3,''))) + ltrim(rtrim(isnull(c.Address4,''))),
       ltrim(rtrim(isnull(c.Phone1,''))) + ltrim(rtrim(isnull(c.Phone2,''))),
       null, null,null,null,null, null,null,null,0,
       f.Short, 
       null,
       NULL, 
       NULL
       FROM STORER c( nolock)
       LEFT JOIN Codelkup f (nolock) ON c.Storerkey = f.Code and f.listname ='STRDOMAIN'  
       WHERE c.storerkey = @c_Storerkey
  END

  SELECT *, ISNULL(@c_exparrivaldate,'')
  FROM #POD
END

GO