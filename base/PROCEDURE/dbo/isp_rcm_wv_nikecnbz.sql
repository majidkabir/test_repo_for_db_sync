SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_RCM_WV_NikeCNBZ                                */    
/* Creation Date: 19-OCT-2018                                          */    
/* Copyright: LF                                                        */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose:  WMS-6727 - NIKECN direct ship to BZ allocation pickdetail  */  
/*        out RCM trigger point                                         */    
/*                                                                      */     
/* Called By: WaveKey RCM configure at listname 'RCMConfig'             */     
/*                                                                      */    
/* Parameters:                                                          */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */   
/* 19-Sep-2019  WLChooi   1.1   WMS-10618 - New Tablename - ALLOCLP2LOG */
/*                              (WL01)                                  */  
/* 08-Apr-2020  WLChooi   1.2   WMS-12756 - New Tablename - ALLOCLP3LOG */
/*                              (WL02)                                  */ 
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_RCM_WV_NikeCNBZ]    
   @c_Wavekey NVARCHAR(10),       
   @b_success  int OUTPUT,    
   @n_err      int OUTPUT,    
   @c_errmsg   NVARCHAR(225) OUTPUT,    
   @c_code     NVARCHAR(30)=''    
AS    
BEGIN     
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_continue int,    
           @n_cnt int,    
           @n_starttcnt int    
               
   DECLARE @c_Facility NVARCHAR(5),    
           @c_storerkey NVARCHAR(15),  
           @c_LoadKey NVARCHAR(15)      
               
   DECLARE @c_trmlogkey NVARCHAR(10)    

   --WL01 Start
   DECLARE @c_Tablename NVARCHAR(30)

   CREATE TABLE #TableName(
   Tablename    NVARCHAR(30) )

   INSERT INTO #TableName
   SELECT 'ALLOCLPLOG'
   UNION ALL 
   SELECT 'ALLOCLP2LOG'
   UNION ALL              --WL02
   SELECT 'ALLOCLP3LOG'   --WL02
   --WL01 End
                  
   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0     
       
   SELECT TOP 1 @c_Facility = Facility,    
                @c_Storerkey = Storerkey    
   FROM ORDERS (NOLOCK)    
   JOIN WAVEDETAIL WD (NOLOCK) ON WD.ORDERKEY = ORDERS.ORDERKEY  
   WHERE WD.WaveKey = @c_Wavekey   
       
   --EXEC dbo.ispGenTransmitLog3 'ALLOCLPLOG', @c_Loadkey, @c_Facility, @c_StorerKey, ''      
   --     , @b_success OUTPUT      
   --     , @n_err OUTPUT      
   --     , @c_errmsg OUTPUT     
   
   --IF NOT @b_success = 1    
   --BEGIN    
   --   SELECT @n_continue = 3    
   --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
   --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain transmitlogkey. (ntrMBOLHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
   --END    
   --ELSE    
   --BEGIN

   DECLARE CUR_LoadKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT DISTINCT o.Loadkey    
   FROM ORDERS O WITH (NOLOCK)    
   INNER JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LPD.ORDERKEY = O.ORDERKEY)  
   INNER JOIN WAVEDETAIL WD WITH (NOLOCK) ON (LPD.ORDERKEY = WD.ORDERKEY)  
   WHERE WD.WaveKey = @c_WaveKey  
   
   OPEN CUR_LoadKey    
   
   FETCH NEXT FROM CUR_LoadKey INTO @c_loadkey                               
   
   WHILE @@FETCH_STATUS <> -1    
   BEGIN   
       --WL01 Start
      DECLARE Cur_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Tablename
      FROM #TableName
      
      OPEN Cur_Loop
      
      FETCH NEXT FROM Cur_Loop INTO @c_Tablename
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      --WL01 End
 
         SELECT @b_success = 1
         
         EXECUTE nspg_getkey    
         -- Change by June 15.Jun.2004    
         -- To standardize name use in generating transmitlog3..transmitlogkey    
         -- 'Transmitlog3Key'    
         'TransmitlogKey3'    
         , 10    
         , @c_trmlogkey OUTPUT    
         , @b_success   OUTPUT    
         , @n_err       OUTPUT    
         , @c_errmsg    OUTPUT    
         
         IF NOT @b_success = 1
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Unable to Obtain transmitlogkey. (isp_RCM_WV_NikeCNBZ)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
         ELSE
         BEGIN
            INSERT INTO Transmitlog3 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
            VALUES (@c_trmlogkey, @c_Tablename, @c_Loadkey, @c_Facility, @c_StorerKey, '0', '')   --WL01

            --WL01
            --UPDATE Loadplan    
            --SET UserDefine01 = 'Y'    
            --WHERE loadkey = @c_Loadkey     
                
            SET @n_err = @@ERROR    
            
            --IF @n_err <> 0    
            --BEGIN    
            --   SET @n_Continue = 3    
            --END     
         END   
               
         IF @b_success = 0    
            SELECT @n_continue = 3, @n_err = 60098, @c_errmsg = 'isp_RCM_WV_NikeCNBZ: ' + rtrim(@c_errmsg)   

         FETCH NEXT FROM Cur_Loop INTO @c_Tablename
      END
      CLOSE Cur_Loop
      DEALLOCATE Cur_Loop

      IF @n_err = 0 AND @b_success = 1
      BEGIN
         UPDATE Loadplan
         SET UserDefine01 = 'Y'
         WHERE loadkey = @c_Loadkey 
      END 
   
      FETCH NEXT FROM CUR_LoadKey INTO @c_Loadkey    
   END    
   CLOSE CUR_LoadKey    
   DEALLOCATE CUR_LoadKey 

ENDPROC:     
    
   IF @n_continue=3  -- Error Occured - Process And Return    
  BEGIN    
     SELECT @b_success = 0    
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
     BEGIN    
        ROLLBACK TRAN    
     END    
  ELSE    
     BEGIN    
        WHILE @@TRANCOUNT > @n_starttcnt    
        BEGIN    
           COMMIT TRAN    
        END    
     END    
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_WV_NikeCNBZ'    
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
     RETURN    
  END    
  ELSE    
     BEGIN    
        SELECT @b_success = 1    
        WHILE @@TRANCOUNT > @n_starttcnt    
        BEGIN    
           COMMIT TRAN    
        END    
        RETURN    
     END        
END -- End PROC    


GO