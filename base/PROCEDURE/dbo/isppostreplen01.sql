SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPostReplen01                                       */
/* Creation Date: 20-Aug-2019                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-9826 CN UA Post replenishment update ucc status and send   */
/*          UCC replen info to WCS for manual replen backup process        */
/*                                                                         */
/* Called By: PostReplenishment_SP                                         */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-Sep-2019  NJOW01  1.0   WMS-10709 Update pickdetail to status 3      */
/* 30-Oct-2019  NJOW02  1.1   WMS-10647 Exclude update PD UOM7 TO status 3 */
/***************************************************************************/  
CREATE PROC [dbo].[ispPostReplen01]  
(     @c_Replenishmentkey  NVARCHAR(10)   
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   DECLARE @c_ReplenishmentGroup NVARCHAR(10),
           @c_WaveType           NVARCHAR(18),
           @c_UCCNo              NVARCHAR(20),
           @c_Storerkey          NVARCHAR(15),
           @c_Sku                NVARCHAR(20),
           @c_SKUGroup           NVARCHAR(18),
           @c_Facility           NVARCHAR(5),
           @c_Short              NVARCHAR(10),   
           @n_Count              INT,
           @c_WCSStation         NVARCHAR(20),
           @c_PreWCSStation      NVARCHAR(20),
           @c_WCSKey             NVARCHAR(10),
           @c_WCSSequence        NVARCHAR(2),  
           @c_WCSMessage         NVARCHAR(255),           
           @c_DeviceID           NVARCHAR(20),  
           @c_DeviceType         NVARCHAR(20),  
           @c_PutawayZone        NVARCHAR(10),   
           @c_FinalLOC           NVARCHAR(10),                      
           @n_Mobile             INT,
           @n_Func               INT,       
           @c_LangCode           NVARCHAR(3),  
           @n_Step               INT,
           @n_InputKey           INT,
           @c_Wavekey            NVARCHAR(10),
           @c_Pickdetailkey      NVARCHAR(10)
                             
   SET @c_DeviceID = 'WCS'
   SET @c_DeviceType = 'WCS'
   SET @n_Mobile = 0
   SET @n_Func = 0       
   SET @c_LangCode = 'ENG'   
   SET @n_Step = 0
   SET @n_InputKey = 0
   
   BEGIN TRAN
   	
   IF @n_continue IN(1,2)
   BEGIN   	     	
   	  SELECT @c_WaveType = W.WaveType,
   	         @c_ReplenishmentGroup = R.ReplenishmentGroup,
   	         @c_Storerkey = R.Storerkey,
   	         @c_UCCNo = UCC.UCCNo,
   	         @c_Facility = LOC.Facility,
   	         @c_Sku = R.Sku,
   	         @c_SkuGroup = SKU.Susr3,
   	         @c_FinalLoc = R.ToLoc,
   	         @c_Wavekey = R.Wavekey
   	  FROM REPLENISHMENT R (NOLOCK)
   	  JOIN SKU (NOLOCK) ON R.Storerkey = SKU.Storerkey AND R.Sku = SKU.Sku
   	  JOIN UCC (NOLOCK) ON R.Replenishmentkey = UCC.Userdefined10 AND R.Storerkey = UCC.Storerkey AND R.Sku = UCC.Sku
   	  JOIN LOC (NOLOCK) ON R.FromLoc = LOC.Loc
   	  JOIN WAVE W (NOLOCK) ON R.Wavekey = W.Wavekey
   	  WHERE R.Replenishmentkey = @c_Replenishmentkey
   	                 
   	  IF @c_WaveType <> 'PAPER'
   	  BEGIN               
   	     GOTO QUIT_SP
   	  END   	    
   END

   IF @n_continue IN(1,2)
   BEGIN
   	  UPDATE UCC WITH (ROWLOCK)   	
   	  SET Status = '6',
   	      TrafficCop = NULL
   	  WHERE UCCNo = @c_UCCNo
   	  AND Storerkey = @c_Storerkey
   	  AND Sku = @c_Sku
   	  
      SET @n_err = @@ERROR    
      
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 61810-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
         SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table UCC. (ispPostReplen01)'            
      END    	  
   END
   
   IF @n_continue IN(1,2)
   BEGIN
       IF @c_ReplenishmentGroup = 'PACKSTATIO'    
       BEGIN  
          -- To Packing Station  
          SET @c_WCSStation = ''  
            
          SELECT @c_WCSStation = Short                  
          FROM dbo.Codelkup WITH (NOLOCK)   
          WHERE ListName = 'WCSSTATION'  
          AND StorerKey = @c_StorerKey  
          AND Code = 'B2BPACK'  
            
          EXECUTE dbo.nspg_GetKey  
          'WCSKey',  
          10 ,  
          @c_WCSKey          OUTPUT,  
          @b_Success         OUTPUT,  
          @n_Err             OUTPUT,  
          @c_ErrMsg          OUTPUT  
            
          IF @b_Success <> 1  
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61820-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Getkey Failed. (ispPostReplen01)'           
             GOTO QUIT_SP               	
          END  
            
          SET @c_WCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
          SET @c_WCSMessage = CHAR(2) +   + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_ReplenishmentKey + '|' + @c_WCSStation + '|' + CHAR(3)     
         
          EXEC [RDT].[rdt_GenericSendMsg]  
           @nMobile      = @n_Mobile        
          ,@nFunc        = @n_Func          
          ,@cLangCode    = @c_LangCode      
          ,@nStep        = @n_Step          
          ,@nInputKey    = @n_InputKey      
          ,@cFacility    = @c_Facility      
          ,@cStorerKey   = @c_StorerKey     
          ,@cType        = @c_DeviceType         
          ,@cDeviceID    = @c_DeviceID  
          ,@cMessage     = @c_WCSMessage       
          ,@nErrNo       = @n_Err         OUTPUT  
          ,@cErrMsg      = @c_ErrMsg      OUTPUT     
            
          IF @n_Err <> 0   
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61830-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Send Message Failed. (ispPostReplen01)'             	
          END              
       END  
       ELSE IF @c_ReplenishmentGroup = 'PTS'    
       BEGIN  
          SET @n_Count = 1   
                        
          SELECT @c_Short = Short   
          FROM Codelkup WITH (NOLOCK)   
          WHERE ListName = 'SKUGroup'  
          AND StorerKey = 'UA'  
          AND Code = @c_SKUGroup   
              
          DECLARE CUR_PTS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR               
             SELECT L.PutawayZone 
             FROM rdt.rdtPTLStationLog PTL WITH (NOLOCK)
             JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.OrderKey = PTL.OrderKey --AND PD.WaveKey = PTL.WaveKey   
             JOIN dbo.WaveDetail WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey AND WD.Wavekey = PTL.Wavekey
             JOIN dbo.LOC L WITH (NOLOCK) ON L.Facility = @c_Facility AND L.Loc = PTL.LOC  
             WHERE PTL.WaveKey = @c_WaveKey  
             AND PTL.StorerKey = @c_StorerKey   
             AND PD.DropID = @c_UCCNo   
             AND PTL.UserDefine02 = @c_Short  
             GROUP BY L.PutawayZone              
                         
          OPEN CUR_PTS   
          
          FETCH NEXT FROM CUR_PTS INTO @c_PutawayZone  
          WHILE @@FETCH_STATUS <> -1  
          BEGIN  
             SET @c_WCSStation  = ''  
               
             SELECT @c_WCSStation = Short                  
             FROM dbo.Codelkup WITH (NOLOCK)   
             WHERE ListName = 'WCSSTATION'  
             AND StorerKey = @c_StorerKey  
             AND Code = @c_PutawayZone   
       
             IF @c_WCSStation <> ''
             BEGIN                  
                EXECUTE dbo.nspg_GetKey  
                   'WCSKey',  
                   10 ,  
                   @c_WCSKey           OUTPUT,  
                   @b_Success          OUTPUT,  
                   @n_Err              OUTPUT,  
                   @c_ErrMsg           OUTPUT  
                  
                IF @b_Success <> 1  
                BEGIN  
                   SET @n_continue = 3    
                   SET @n_err = 61840-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                   SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Getkey Failed. (ispPostReplen01)'             	
                   GOTO QUIT_SP                   
                END  
               
                SET @c_WCSSequence =  RIGHT('00'+CAST(@n_Count AS VARCHAR(2)),2)  
                SET @c_WCSMessage = CHAR(2) + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_Replenishmentkey + '|' + @c_WCSStation + '|' + CHAR(3)   
            
                EXEC [RDT].[rdt_GenericSendMsg]  
                 @nMobile      = @n_Mobile        
                ,@nFunc        = @n_Func          
                ,@cLangCode    = @c_LangCode      
                ,@nStep        = @n_Step          
                ,@nInputKey    = @n_InputKey      
                ,@cFacility    = @c_Facility      
                ,@cStorerKey   = @c_StorerKey     
                ,@cType        = @c_DeviceType         
                ,@cDeviceID    = @c_DeviceID  
                ,@cMessage     = @c_WCSMessage       
                ,@nErrNo       = @n_Err         OUTPUT  
                ,@cErrMsg      = @c_ErrMsg      OUTPUT    
               
                IF @n_Err <> 0   
                BEGIN  
                   SET @n_continue = 3    
                   SET @n_err = 61850-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                   SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Send Message Failed. (ispPostReplen01)'             	
                END  
       
                SET @n_Count = @n_Count + 1   
             END  
                      
             SET @c_PreWCSStation = @c_WCSStation  
               
             FETCH NEXT FROM CUR_PTS INTO @c_PutawayZone  
          END  
          CLOSE CUR_PTS  
          DEALLOCATE CUR_PTS                
       END  
       /*ELSE IF @c_ReplenishmentGroup = 'PACKSTATIO' AND ISNULL(@c_WaveKey,'')  = ''   
       BEGIN              
          SET @n_Count = 1   
            
          -- To Single Packing Area  
          SET @c_WCSStation = ''  
            
          SELECT @c_WCSStation = Short                  
          FROM dbo.Codelkup WITH (NOLOCK)   
          WHERE ListName = 'WCSSTATION'  
          AND StorerKey = @c_StorerKey  
          AND Code = 'SINGLE'  
            
          EXECUTE dbo.nspg_GetKey  
          'WCSKey',  
          10 ,  
          @c_WCSKey           OUTPUT,  
          @b_Success          OUTPUT,  
          @n_Err              OUTPUT,  
          @c_ErrMsg           OUTPUT  
            
          IF @bSuccess <> 1  
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61833-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Getkey Failed. (ispPostReplen01)'           
             GOTO QUIT_SP               	
          END  
            
          SET @c_WCSSequence = RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)  
          SET @c_WCSMessage = CHAR(2) +   + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_ReplenishmentKey + '|' + @c_WCSStation + '|' + CHAR(3)     
         
          EXEC [RDT].[rdt_GenericSendMsg]  
           @nMobile      = @n_Mobile        
          ,@nFunc        = @n_Func          
          ,@cLangCode    = @c_LangCode      
          ,@nStep        = @n_Step          
          ,@nInputKey    = @n_InputKey      
          ,@cFacility    = @c_Facility      
          ,@cStorerKey   = @c_StorerKey     
          ,@cType        = @c_DeviceType         
          ,@cDeviceID    = @c_DeviceID  
          ,@cMessage     = @c_WCSMessage       
          ,@nErrNo       = @n_Err         OUTPUT  
          ,@cErrMsg      = @c_ErrMsg      OUTPUT     
            
          IF @n_Err <> 0   
          BEGIN         
             SET @n_continue = 3    
             SET @n_err = 61835-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Send Message Failed. (ispPostReplen01)'             	
          END  
       END*/  
       ELSE IF @c_ReplenishmentGroup = 'PICKLOC'  
       BEGIN              
          SET @n_Count = 1   
            
          SET @c_PutawayZone = ''    
          SET @c_WCSStation = ''   
            
          SELECT @c_PutawayZone = PutawayZone   
          FROM dbo.Loc WITH (NOLOCK)   
          WHERE Facility = @c_Facility   
          AND Loc = @c_FinalLOC  
            
          SELECT @c_WCSStation = Short                  
          FROM dbo.Codelkup WITH (NOLOCK)   
          WHERE ListName = 'WCSSTATION'  
          AND StorerKey = @c_StorerKey  
          AND Code = @c_PutawayZone  
                        
          EXECUTE dbo.nspg_GetKey  
          'WCSKey',  
          10 ,  
          @c_WCSKey           OUTPUT,  
          @b_Success          OUTPUT,  
          @n_Err              OUTPUT,  
          @c_ErrMsg           OUTPUT  
            
          IF @b_Success <> 1  
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61860-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Getkey Failed. (ispPostReplen01)'        
             GOTO QUIT_SP     	
          END  
            
          SET @c_WCSSequence = RIGHT('00'+CAST(@n_Count AS VARCHAR(2)),2)  
          SET @c_WCSMessage = CHAR(2) + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_Replenishmentkey + '|' + @c_WCSStation + '|' + CHAR(3)   
            
          EXEC [RDT].[rdt_GenericSendMsg]  
           @nMobile      = @n_Mobile        
          ,@nFunc        = @n_Func          
          ,@cLangCode    = @c_LangCode      
          ,@nStep        = @n_Step          
          ,@nInputKey    = @n_InputKey      
          ,@cFacility    = @c_Facility      
          ,@cStorerKey   = @c_StorerKey     
          ,@cType        = @c_DeviceType         
          ,@cDeviceID    = @c_DeviceID  
          ,@cMessage     = @c_WCSMessage       
          ,@nErrNo       = @n_Err         OUTPUT  
          ,@cErrMsg      = @c_ErrMsg      OUTPUT     
            
          IF @n_Err <> 0   
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61870-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Send Message Failed. (ispPostReplen01)'             	
          END              
       END     	
   END 
   
   --NJOW01
   IF @n_continue IN(1,2)
   BEGIN
       DECLARE CUR_PICK CURSOR LOCAL READ_ONLY FAST_FORWARD FOR               
          SELECT P.Pickdetailkey
          FROM REPLENISHMENT R (NOLOCK)
          JOIN WAVEDETAIL WD (NOLOCK) ON R.Wavekey = WD.Wavekey
          JOIN PICKDETAIL P (NOLOCK) ON WD.Orderkey = P.Orderkey AND R.ToLoc = P.Loc AND R.Lot = P.Lot  
          WHERE R.Replenishmentkey = @c_Replenishmentkey
          AND P.Status < '3'      
          AND P.UOM <> '7' --NJOW02
          
       OPEN CUR_PICK   
       
       FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey  
       
       WHILE @@FETCH_STATUS <> -1
       BEGIN
       	  UPDATE PICKDETAIL WITH (ROWLOCK)
       	  SET Status = '3'
       	  WHERE Pickdetailkey = @c_Pickdetailkey

          IF @n_Err <> 0   
          BEGIN  
             SET @n_continue = 3    
             SET @n_err = 61880-- Should Be Set To The SQL Errmessage but I don't know how to do so. 
             SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Update Failed On Table Pickdetail. (ispPostReplen01)'            
          END              
       	  
          FETCH NEXT FROM CUR_PICK INTO @c_Pickdetailkey  
       END
       CLOSE CUR_PICK
       DEALLOCATE CUR_PICK                 
   END
        
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPostReplen01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
        COMMIT TRAN
      END 
      RETURN
   END 
END

GO