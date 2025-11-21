SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_sorting_Rpt_LOR_rdt                            */    
/* Creation Date:  07-JUN-2022                                          */    
/* Copyright: LFL                                                       */    
/* Written by: CSCHONG                                                  */    
/*                                                                      */    
/* Purpose:WMS-19780-[TW]LOR_SortReport_New                             */    
/*                                                                      */    
/* Input Parameters: @c_PTLPL_station  - Rdt.RdtPTLPieceLog.station     */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  None                                                 */    
/*                                                                      */    
/* Usage:  Used for report dw = r_dw_sorting_rpt_LOR_RDT                */  
/*                                                                      */   
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
/* 07-JUN-2022   CSCHONG      Devops Scripts Combine                    */
/************************************************************************/    
CREATE PROC [dbo].[isp_sorting_Rpt_LOR_rdt] (    
     @c_PTLPL_station   NVARCHAR(20),
     @c_Type            NVARCHAR(5) = 'H',
     @c_orderkey        NVARCHAR(20) = '',
     @c_loc             NVARCHAR(10) = ''
      
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


   DECLARE @c_station         NVARCHAR(20)
          ,@c_loadkey         NVARCHAR(20)
          ,@c_Getorderkey     NVARCHAR(20)
      
   SET @n_StartTCnt = @@TRANCOUNT    

   WHILE @@TRANCOUNT > 0     
   BEGIN    
      COMMIT TRAN    
   END
   
   CREATE TABLE #TMP_SORTRPTTABLE
                                 ( PTLPL_Loadkey     NVARCHAR(20),
                                   PTLPL_station     NVARCHAR(20),
                                   PTLPL_Addwho      NVARCHAR(256),
                                   RDTUSerFNAME      NVARCHAR(256),
                                   ADDDATE           DATETIME,
                                   PRNDATE           DATETIME,
                                   DPF_LOC           NVARCHAR(10),
                                   PTLPL_ORDERKEY    NVARCHAR(20)

                                 )

   CREATE TABLE #TMP_SORTRPTBLPD
                              ( Orderkey          NVARCHAR(20),
                                ORDLineNo         NVARCHAR(10),
                                SKU               NVARCHAR(20),
                                SDESCR            NVARCHAR(120),
                                PQTY              INT,
                                PLOC              NVARCHAR(10)
                              )


   CREATE TABLE #TMP_SORTRPTBLLLI
                                    ( RowNo             INT,
                                      SKU               NVARCHAR(20),
                                      LOC               NVARCHAR(10),
                                      QTY               INT,
                                      Orderkey          NVARCHAR(20),
                                      SDESCR            NVARCHAR(120)
                                    )

   INSERT INTO #TMP_SORTRPTTABLE
   (
         PTLPL_Loadkey,
         PTLPL_station,
         PTLPL_Addwho,
         RDTUSerFNAME,
         ADDDATE,
         PRNDATE,
         DPF_LOC,
         PTLPL_ORDERKEY
   )

         SELECT RPL.LoadKey,RPL.Station,RPL.AddWho,RU.FullName,RPL.AddDate,GETDATE(),DPF.LOC,RPL.OrderKey
         FROM Rdt.RdtPTLPieceLog RPL WITH (NOLOCK)
         JOIN DeviceProFile DPF WITH (NOLOCK) ON DPF.DeviceID = RPL.Station AND DPF.DevicePosition=RPL.Position
         JOIN rdt.RDTUser RU WITH (NOLOCK) ON RU.UserName=RPL.AddWho
         WHERE  RPL.Station=@c_PTLPL_station

            DECLARE CUR_PTL_orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PTLPL_station,PTLPL_Loadkey,PTLPL_ORDERKEY
            FROM #TMP_SORTRPTTABLE 
            WHERE PTLPL_station = @c_PTLPL_station
            ORDER BY PTLPL_station,PTLPL_Loadkey,PTLPL_ORDERKEY

               OPEN CUR_PTL_orderkey
               FETCH NEXT FROM CUR_PTL_orderkey INTO @c_station,@c_loadkey, @c_Getorderkey

            WHILE @@FETCH_STATUS <> -1
            BEGIN

         INSERT INTO #TMP_SORTRPTBLPD
         (
               Orderkey,
               ORDLineNo,
               SKU,
               SDESCR,
               PQTY,
               PLOC
         )
         SELECT @c_Getorderkey,PD.OrderLineNumber,PD.Sku,s.DESCR,SUM(pd.Qty),pd.Loc
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         --JOIN #TMP_SORTRPTTABLE ST ON ST.PTLPL_ORDERKEY=PD.OrderKey
         JOIN SKU S WITH (NOLOCK) ON s.StorerKey=pd.Storerkey AND s.sku = pd.Sku
         --WHERE ST.PTLPL_station =@c_PTLPL_station
         --AND ST.PTLPL_Loadkey = @c_loadkey
         where PD.ORDERKEY = @c_Getorderkey
         AND PD.CaseID=''
         GROUP BY PD.OrderLineNumber,PD.Sku,s.DESCR,pd.Loc


            FETCH NEXT FROM CUR_PTL_orderkey INTO @c_station,@c_loadkey, @c_Getorderkey
            END        
        
            CLOSE CUR_PTL_orderkey        
            DEALLOCATE CUR_PTL_orderkey   

         INSERT INTO #TMP_SORTRPTBLLLI
         (
               RowNo,
               SKU,
               LOC,
               QTY,
               Orderkey,
               SDESCR 
         )
         Select ROW_NUMBER() Over (PARTITION BY pd.orderkey,SL.Sku,s.DESCR Order By Sum(SL.Qty - SL.QtyAllocated - SL.QtyPicked) Desc) As RowNumber , SL.Sku , SL.Loc , 
                SUM(SL.Qty - SL.QtyAllocated - SL.QtyPicked) As Qty ,pd.OrderKey,s.DESCR
         FROM  PickDetail PD WITH (NoLock) 
               Left Join SkuxLoc SL WITH (NoLock)  On PD.Sku = SL.Sku And PD.Storerkey = SL.Storerkey
               Left Join Loc LC  WITH (NoLock) On SL.Loc = LC.Loc
               JOIN SKU S WITH (NOLOCK) ON s.StorerKey=pd.Storerkey AND s.sku = pd.Sku
               JOIN #TMP_SORTRPTTABLE ST ON ST.PTLPL_ORDERKEY=PD.OrderKey
            Where Caseid = '' And LC.HostwhCode = 'U-SL01' AND SL.LocationType='PICK'
            Group By pd.OrderKey,SL.Sku,s.DESCR , SL.Loc Having Sum(SL.Qty - SL.QtyAllocated -SL.QtyPicked) > 0

   IF @c_Type = 'H'
   BEGIN
      SELECT DISTINCT PTLPL_Loadkey,
             PTLPL_station,
             PTLPL_Addwho,
             RDTUSerFNAME,
             ADDDATE,
             PRNDATE,
             DPF_LOC,
             PTLPL_ORDERKEY
      FROM #TMP_SORTRPTTABLE ST
      JOIN #TMP_SORTRPTBLPD SP ON SP.Orderkey = ST.PTLPL_ORDERKEY
      ORDER BY  PTLPL_station,PTLPL_Loadkey,PTLPL_ORDERKEY,DPF_LOC
   END  
   ELSE IF @c_Type = 'D1'
   BEGIN
         SELECT   SKU,
                  SDESCR,
                  orderkey,
                  PQTY,
                  ORDLineNo,                 
                  PLOC
          FROM #TMP_SORTRPTBLPD
          WHERE Orderkey = @c_orderkey
         -- AND PLOC = @c_loc
          ORDER BY Orderkey,ORDLineNo,SKU,PLOC

   END
   ELSE IF @c_Type='D2'
   BEGIN
             SELECT  SKU,
                     RowNo,
                     Orderkey,
                     QTY,
                     LOC,
                     SDESCR
            FROM #TMP_SORTRPTBLLLI
            WHERE Orderkey = @c_orderkey
           -- AND LOC = @c_loc
            AND RowNo <=3
          ORDER BY Orderkey,RowNo
   END     

   QUIT_SP:    

   
   IF OBJECT_ID('tempdb..#TMP_SORTRPTTABLE') IS NOT NULL 
      DROP TABLE #TMP_SORTRPTTABLE 

   IF OBJECT_ID('tempdb..#TMP_SORTRPTBLPD') IS NOT NULL 
      DROP TABLE #TMP_SORTRPTBLPD 


   IF OBJECT_ID('tempdb..#TMP_SORTRPTBLLLI') IS NOT NULL 
      DROP TABLE #TMP_SORTRPTBLLLI 

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_sorting_Rpt_LOR_rdt'      
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