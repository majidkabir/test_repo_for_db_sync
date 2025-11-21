SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_LoadManifestSum04                       		    */
/* Creation Date:                                     			    	    	*/
/* Copyright: IDS                                                       */
/* Written by:                                             			    	  */
/*                                                                      */
/* Purpose:                                                             */
/* Input Parameters:  @c_mbolkey  - MBOLkey 										        */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_dmanifest_sum04           		    	*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author    Ver.  Purposes                                 */
/* 30June2010  GTGOH     1.0   SOS#179724 - Add Storer.Company (GOH01)  */
/* 15-Aug-2011 YTWan     1.1   SOS#222245 - Standard getting report logo*/
/*                             (Wan01)                                  */
/* 28-Jun-2012 NJOW01    1.2   Fix - Convert notes field to varchar     */
/* 02-Sep-2014 NJOW02    1.3   318865-add CN barcode and susr1 with     */
/*                             config                                   */
/************************************************************************/

 CREATE PROC [dbo].[nsp_LoadManifestSum04] (  
    @c_mbolkey NVARCHAR(10)  
 )  
 AS  
 BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 
       
   DECLARE  @n_totalorders int  
        ,@n_totalcust  int  
  
   SELECT MBOL.mbolkey,  
         MBOL.vessel,      
         MBOL.Departuredate,     
         MBOL.carrierkey,  
         MBOLDETAIL.loadkey,   
         MBOLDETAIL.orderkey,  
         MBOLDETAIL.externorderkey,  
         MBOLDETAIL.description,  
         MBOLDETAIL.deliverydate,  
         ORDERS.ContainerQty,  
         --ORDERS.DOOR,  
         CASE WHEN ISNULL(CLR.Code,'') <> '' THEN LEFT(LTRIM(ORDERS.DOOR), 8) ELSE ORDERS.DOOR END AS DOOR, --NJOW02  
         CONVERT(NVARCHAR(255),ORDERS.Notes) AS Notes,  --NJOW01
         CONVERT(NVARCHAR(255),ORDERS.Notes2) AS Notes2, --NJOW01            
         TotalOrders = 0,  
         TotalCust = 0,  
         Storer.Company,    --GOH01
         ORDERS.StorerKey, 
         CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS Showcnbarcode, --NJOW02 
         Storer.Susr1 --NJOW01                                                                             --(Wan01)
   INTO #RESULT  
   FROM MBOL (NOLOCK)   
   INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.mbolkey = MBOLDETAIL.mbolkey)  
   INNER JOIN ORDERS (NOLOCK) ON (MBOL.mbolkey = ORDERS.mbolkey and MBOLDetail.OrderKey = ORDERS.OrderKey)  
   INNER JOIN STORER (NOLOCK) ON  (ORDERS.StorerKey = Storer.StorerKey) --GOH01
   LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'SHOWCNBARCODE' 
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_dmanifest_sum04' AND ISNULL(CLR.Short,'') <> 'N')
   WHERE MBOL.mbolkey = @c_mbolkey  
  
   SELECT @n_totalorders = COUNT(*), @n_totalcust = COUNT(DISTINCT description)  
   FROM #RESULT (NOLOCK)  
   WHERE mbolkey = @c_mbolkey  
     
   UPDATE #RESULT  
   SET TotalOrders = @n_totalorders,  
  TotalCust = @n_totalcust  
   WHERE mbolkey = @c_mbolkey  
  
   SELECT *  
   FROM #RESULT  
   ORDER BY loadkey, orderkey   
  
   DROP TABLE #RESULT  
  
  
END  
  
  

GO