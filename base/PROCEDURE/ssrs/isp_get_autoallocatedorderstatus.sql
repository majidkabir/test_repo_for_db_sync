SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Get_AutoAllocatedOrderStatus                   */
/* Creation Date: 2019-08-13                                            */
/* Copyright: LF Logistics                                              */
/* Written by:wtshong                                                   */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* GIT Version: 1.0                                                     */
/*                                                                      */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 2019-08-13       1.0      Initial Version								      */
/************************************************************************/
CREATE PROCEDURE [SSRS].[isp_Get_AutoAllocatedOrderStatus]   
AS  
BEGIN  
 SET NOCOUNT ON;  
  
   IF OBJECT_ID('tempdb..#O') IS NOT NULL  
       DROP TABLE #O  
     
   CREATE TABLE #O (  
    StorerKey      NVARCHAR(15) NULL,   
    Company        NVARCHAR(60) NULL,   
    Facility       NVARCHAR(5)  NULL,  
    Submitted      INT NULL,  
    Pending        INT NULL,   
    NoOfOrders     INT NULL,   
    PendingJobs    INT NULL,   
    InProgrssJob   INT NULL )  
  
   DECLARE @c_StorerKey       NVARCHAR(15) = ''   
         , @c_Facility        NVARCHAR(5) = ''  
         , @n_PendingJobs     INT = 0   
         , @n_InProgressJobs  INT = 0   
              
   DECLARE CUR_STORER_FACILITY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT blph.StorerKey ,blph.Facility  
   FROM   V_Build_Load_Parm_Header AS blph WITH(NOLOCK)  
   WHERE  BL_BuildType = 'BACKENDALLOC'  
      AND blph.BL_ActiveFlag = '1'   
     
   OPEN CUR_STORER_FACILITY  
     
   FETCH FROM CUR_STORER_FACILITY INTO @c_StorerKey, @c_Facility  
     
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @n_PendingJobs = 0   
      SET @n_InProgressJobs = 0   
        
      SELECT @n_PendingJobs    = ISNULL(SUM(CASE WHEN aabj.[Status] = '0' THEN 1 ELSE 0 END),0),  
             @n_InProgressJobs = ISNULL(SUM(CASE WHEN aabj.[Status] = '1' THEN 1 ELSE 0 END),0)    
      FROM AutoAllocBatchJob AS aabj WITH(NOLOCK)  
      WHERE aabj.Storerkey = @c_StorerKey   
      AND aabj.Facility = @c_Facility  
      AND aabj.[Status] IN ('0','1')            
        
      INSERT INTO #O (StorerKey, Company, Facility, Submitted, Pending, NoOfOrders, PendingJobs, InProgrssJob)   
      SELECT O.StorerKey  
            ,S.Company        
            ,O.Facility  
            ,SUM(CASE WHEN aabd.RowRef IS NOT NULL THEN 1 ELSE 0 END) AS Submitted  
            ,SUM(CASE WHEN aabd.RowRef IS NULL THEN 1 ELSE 0 END) AS Pending  
            ,COUNT(DISTINCT O.OrderKey) AS NoOfOrders  
            ,@n_PendingJobs  
            ,@n_InProgressJobs  
      FROM   ORDERS O WITH (NOLOCK)  
      JOIN STORER S WITH (NOLOCK) ON  O.StorerKey = S.StorerKey  
      LEFT OUTER JOIN AutoAllocBatchDetail AS aabd WITH(NOLOCK) ON  aabd.OrderKey = O.OrderKey  
      WHERE o.DocType = 'E'  
        AND o.[Status] = '0'  
        AND (o.LoadKey='' OR o.LoadKey IS NULL)   
        AND o.StorerKey = @c_StorerKey   
        AND o.Facility  = @c_Facility   
      GROUP BY o.StorerKey ,O.Facility ,S.Company         
     
    FETCH FROM CUR_STORER_FACILITY INTO @c_StorerKey, @c_Facility  
   END  
     
   CLOSE CUR_STORER_FACILITY  
   DEALLOCATE CUR_STORER_FACILITY  
   
  
   SELECT O.*  
   FROM   #O O  
  
END  

GRANT EXECUTE ON [SSRS].[isp_Get_AutoAllocatedOrderStatus] TO NSQL  

GO